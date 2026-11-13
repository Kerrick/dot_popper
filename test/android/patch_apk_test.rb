# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "zlib"
require_relative "../../script/android_patch_apk"

# script/android_patch_apk.rb puts this commit's game into an app built
# for another commit: only the game's files in the app's fledge.zip
# change, and every other entry of both archives is kept byte for byte.
class PatchApkTest < Minitest::Test
  P = AndroidPatch

  def setup
    @project = Dir.mktmpdir("dot-popper-phone")
    FileUtils.mkdir_p(File.join(@project, "game/dot_popper/lib"))
    File.write(File.join(@project, "game/dot_popper/main.rb"), "new main\n")
    File.write(File.join(@project, "game/dot_popper/lib/rules.rb"), "new rules\n")
    File.write(File.join(@project, "main.rb"), "new kit\n")
  end

  def teardown = FileUtils.rm_rf(@project)

  def test_the_game_and_the_kit_are_this_commits_and_the_rest_is_kept
    patched = P.entries(P.patch(base, @project))
    inner = P.entries(P.data(patched.find { it.name == P::ASSET }))

    assert_equal %w[app/ app/Gemfile lib/ruby/x.rb app/game/dot_popper/ app/game/dot_popper/lib/ app/game/dot_popper/lib/rules.rb
                    app/game/dot_popper/main.rb app/main.rb], inner.map(&:name)
    assert_equal "new rules\n", P.data(inner.find { it.name == "app/game/dot_popper/lib/rules.rb" })
    assert_equal "new kit\n", P.data(inner.find { it.name == "app/main.rb" })
    old = P.entries(old_zip)
    %w[app/ app/Gemfile lib/ruby/x.rb].each { |name| assert_equal old.find { it.name == name }.raw, inner.find { it.name == name }.raw }
  end

  def test_the_other_entries_are_kept_byte_for_byte_and_the_old_signature_left_out
    old = P.entries(base)
    patched = P.entries(P.patch(base, @project))

    assert_equal ["classes.dex", "lib/x86_64/libSDL3.so", "META-INF/androidx.core.version", P::ASSET], patched.map(&:name)
    %w[classes.dex lib/x86_64/libSDL3.so META-INF/androidx.core.version].each do |name|
      assert_equal old.find { it.name == name }.raw, patched.find { it.name == name }.raw
    end
  end

  def test_what_unzip_reads_is_what_was_written
    skip "no unzip here" unless system("unzip", "-v", out: File::NULL, err: File::NULL)
    apk = File.join(@project, "out.apk")
    File.binwrite(apk, P.patch(base, @project))
    assert system("unzip", "-tqq", apk, out: File::NULL), "unzip finds the app broken"
    Dir.chdir(@project) { assert system("unzip", "-qo", apk, P::ASSET) }
    assert system("unzip", "-tqq", File.join(@project, P::ASSET), out: File::NULL), "unzip finds fledge.zip broken"
  end

  def test_two_apps_holding_the_same_files_are_the_same_and_a_changed_game_file_is_named
    patched = P.patch(base, @project)
    assert_empty P.differences(patched, P.patch(base, @project))

    File.write(File.join(@project, "game/dot_popper/lib/rules.rb"), "other rules\n")
    assert_equal ["assets/fledge.zip!app/game/dot_popper/lib/rules.rb"], P.differences(patched, P.patch(base, @project))
  end

  def test_a_file_that_is_not_a_zip_is_refused
    assert_raises(ArgumentError) { P.patch("not a zip", @project) }
  end

  private

  def old_zip
    P.write([P.stored("app/"), P.stored("app/Gemfile", "gems\n"), P.stored("app/game/dot_popper/"),
             P.stored("app/game/dot_popper/main.rb", "old main\n"), P.stored("app/main.rb", "old kit\n"),
             P.stored("lib/ruby/x.rb", "ruby\n")])
  end

  def base
    @base ||= P.write([deflated("classes.dex", "dex" * 100), P.stored("lib/x86_64/libSDL3.so", "\x7fELF".b),
                       P.stored("META-INF/CERT.SF", "sig"), P.stored("META-INF/androidx.core.version", "1"),
                       P.stored(P::ASSET, old_zip)])
  end

  # An entry compressed with deflate, with its sizes after its data, as
  # some archivers write them.
  def deflated(name, text)
    data = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, -Zlib::MAX_WBITS).then { it.deflate(text, Zlib::FINISH) }
    crc = Zlib.crc32(text)
    local = ["PK\x03\x04".b, 20, 8, 8, 0, 0x21, 0, 0, 0, name.bytesize, 0].pack("a4vvvvvVVVvv")
    descriptor = ["PK\x07\x08".b, crc, data.bytesize, text.bytesize].pack("a4VVV")
    central = ["PK\x01\x02".b, 20, 20, 8, 8, 0, 0x21, crc, data.bytesize, text.bytesize, name.bytesize, 0, 0, 0, 0, 0, 0]
              .pack("a4vvvvvvVVVvvvvvVV")
    P::Entry.new(name, local + name.b + data + descriptor, central + name.b)
  end
end
