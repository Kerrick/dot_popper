# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

# What a package holds that its channel does not need
# (script/channel_contents.rb), read from an app laid out here as
# `lota fuse` lays one out: the game's copy in game/dot_popper, beside
# files of Ruby's own.
class ChannelContentsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "script", "channel_contents.rb")
  require SCRIPT
  require_relative "../script/set_build_channel"

  def setup
    @app = Dir.mktmpdir("dot_popper_app")
    @game = File.join(@app, "Dot Popper", "app", "game", "dot_popper")
    FileUtils.mkdir_p(@game)
    FileUtils.cp_r(File.join(ROOT, "lib"), @game)
    # Ruby's own files may say anything; only the game's are read for Ruby's pieces.
    ruby = File.join(@app, "Dot Popper", "app", "ruby", "lib")
    FileUtils.mkdir_p(ruby)
    File.write(File.join(ruby, "openssl_doc.rb"), "# -----BEGIN PRIVATE KEY----- LicenseKey\n")
  end

  def teardown = FileUtils.rm_rf(@app)

  def run_script(*args)
    out, status = Open3.capture2e(RbConfig.ruby, SCRIPT, *args)
    [status.success?, out]
  end

  def test_a_store_build_today_holds_the_fakes_test_keys_and_website_checkout
    ok, out = run_script("list", "mac-app-store", @app)

    assert ok, out
    assert_match %r{^the test build's part .*\n  file lib/dot_popper/test_build$}, out
    assert_match %r{  text lib/dot_popper/test_build/receipt_test_key\.rb: BEGIN PRIVATE KEY x1}, out
    assert_match %r{^the website checkout .*\n  file lib/dot_popper/website_store\.rb$}, out
    assert_match(/^the Microsoft Store's license /, out)
    refute_match(/^Apple's receipts/, out)
    refute_match(/openssl_doc/, out)
  end

  def test_a_test_build_needs_its_fakes_and_the_website_checkout
    ok, out = run_script("list", "test", @app)

    assert ok, out
    refute_match(/^the test build's part|^the fake store|^the test keys|^the website checkout|^license keys/, out)
    assert_match(/^Apple's receipts \(needed by app-store, mac-app-store\)/, out)
  end

  def test_a_build_for_sale_leaves_out_the_privacy_declarations_the_game_never_loads
    expected = %w[lib/dot_popper/privacy/declared.rb lib/dot_popper/privacy/document.rb lib/dot_popper/privacy/requests.rb]

    DotPopper::Build::CHANNEL_NAMES.each { assert_empty expected - ChannelContents.left_out(it), it }
    assert_empty ChannelContents.left_out("test")
    assert_includes run_script("excludes", "microsoft-store").last, "#{expected.join("\n")}\n"
    assert_equal "", run_script("excludes", "test").last
  end

  # The working copy's own channel, which the fuse action asks for, is a
  # test build's in the repository.
  def test_the_working_copy_leaves_nothing_out
    ok, out = run_script("excludes")

    assert ok, out
    assert_equal "", out
  end

  # Each channel's build, stamped as script/set_build_channel.rb stamps it
  # and loaded as the app loads it (main.rb loads the shell), loads none
  # of what that channel leaves out.
  def test_no_build_for_sale_loads_what_it_leaves_out
    DotPopper::Build::CHANNEL_NAMES.each do |channel|
      FileUtils.rm_rf(File.join(@game, "lib"))
      FileUtils.cp_r(File.join(ROOT, "lib"), @game)
      build = File.join(@game, "lib/dot_popper/build.rb")
      File.write(build, BuildChannel.stamp(File.read(build), channel))
      ChannelContents.left_out(channel).each { FileUtils.rm_rf(File.join(@game, it)) }
      load = 'require "lota"; require "dot_popper"; require "dot_popper/shell"; puts DotPopper::Build::CHANNEL'
      out, status = Open3.capture2e(RbConfig.ruby, "-I", File.join(@game, "lib"), "-e", load)
      skip "Lota isn't installed here (#{out.lines.first})" if !status.success? && out.include?("lota (LoadError)")

      assert status.success?, "#{channel}: #{out}"
      assert_equal channel, out.lines.last.chomp
    end
  end

  def test_every_left_out_file_is_in_the_repository
    ChannelContents::PIECES.select(&:apart).flat_map(&:files).each { assert_path_exists File.join(ROOT, it) }
  end

  def test_check_fails_when_a_left_out_file_comes_back
    ok, out = run_script("check", "mac-app-store", @app)

    refute ok, out
    assert_match %r{FAIL .* holds lib/dot_popper/privacy/declared\.rb \(privacy declarations the game never loads\), which a mac-app-store build leaves out}, out

    ChannelContents.left_out("mac-app-store").each { FileUtils.rm_rf(File.join(@game, it)) }
    ok, out = run_script("check", "mac-app-store", @app)

    assert ok, out
  end

  # A build for sale holds no word of what it leaves out whole: a test
  # key's name in a file it carries fails the check.
  def test_check_fails_when_a_build_for_sale_names_a_test_key
    ChannelContents.left_out("website").each { FileUtils.rm_rf(File.join(@game, it)) }
    ok, out = run_script("check", "website", @app)

    assert ok, out
    File.write(File.join(@game, "lib/dot_popper/stray.rb"), "# Continuity::TestKeys::LICENSE\n")
    ok, out = run_script("check", "website", @app)

    refute ok, out
    assert_match %r{FAIL .* holds lib/dot_popper/stray\.rb, which names the test keys \(TestKeys\?\)}, out
  end

  def test_an_unknown_channel_or_a_missing_folder_is_refused
    refute run_script("list", "steam", @app).first
    refute run_script("list", "website", File.join(@app, "nowhere")).first
    refute run_script("excludes", "steam").first
  end
end
