# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"
require "yaml"

# A release checks the app it built (script/check_build.rb), laid out here
# as `lota fuse` lays one out: the game's copy in game/dot_popper.
class CheckBuildTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "script", "check_build.rb")

  def setup
    require "lota"
    @app = Dir.mktmpdir("dot_popper_app")
    @game = File.join(@app, "Dot Popper", "app", "game", "dot_popper")
    FileUtils.mkdir_p(@game)
    FileUtils.cp_r(%w[lib fledge.yml].map { File.join(ROOT, it) }, @game)
    @version = YAML.load_file(File.join(ROOT, "fledge.yml")).fetch("version").to_s
  rescue LoadError => e
    skip "Lota isn't installed here (#{e.message})"
  end

  def teardown = @app && FileUtils.rm_rf(@app)

  def stamp(channel) = edit("lib/dot_popper/build.rb", "    CHANNEL = nil\n", "    CHANNEL = #{channel.inspect}\n")

  def edit(path, from, to)
    file = File.join(@game, path)
    source = File.read(file)
    assert_includes source, from
    File.write(file, source.sub(from, to))
  end

  def check(channel, version = @version)
    out, status = Open3.capture2e(RbConfig.ruby, SCRIPT, channel, version, @app)
    [status.success?, out]
  end

  def test_a_website_build_passes_as_a_website_build
    stamp("website")
    ok, out = check("website")

    assert ok, out
    refute_match(/FAIL/, out)
  end

  # The repository's own code is a test build, and a build for another
  # channel is not this one.
  def test_a_test_build_or_another_channels_build_fails
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL the app was built for "website"/, out)

    stamp("microsoft-store")
    ok, out = check("website")

    refute ok, out
    assert_match(/FAIL the app was built for "website" \(Build::CHANNEL is "microsoft-store"\)/, out)
  end

  def test_a_build_that_trusts_the_test_keys_or_has_another_version_fails
    stamp("website")
    edit("lib/dot_popper/continuity/pins.rb", "PINNED = SETDEF_PINS", "PINNED = TEST_PINS")
    ok, out = check("website", "0.0.1")

    refute ok, out
    assert_match(/FAIL it trusts setdef's own keys/, out)
    assert_match(/FAIL it trusts no test key/, out)
    assert_match(/FAIL no license key signed by a test key unlocks it/, out)
    assert_match(/FAIL its version is 0\.0\.1/, out)
  end

  # Only the channel's own needs: Google Play's build needs the Play key,
  # which a website build does not.
  # The test build's proofs come from this repository, so an app that
  # carries no test keys is still shown refusing what they sign.
  def test_an_app_without_the_test_keys_is_checked_with_the_repositorys
    stamp("website")
    File.write(File.join(@game, "lib/dot_popper/continuity/test_keys.rb"), "# frozen_string_literal: true\n")
    ok, out = check("website")

    assert ok, out
    assert_match(/^ok   a key signed by the test key unlocks a test build$/, out)
    assert_match(/^ok   no license key signed by a test key unlocks it$/, out)
  end

  def test_a_google_play_build_needs_the_play_key
    stamp("google-play")
    ok, out = check("google-play")

    assert_equal DotPopper::Receipt::PLAY_KEYS.any?, ok, out
    assert_match(/it pins the app's Play key/, out)
  end
end
