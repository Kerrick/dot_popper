# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

# A store build's job stamps its channel into a copy of the code before
# fusing (script/set_build_channel.rb). Run on a copy, never this one.
class SetBuildChannelTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @copy = Dir.mktmpdir("dot_popper_channel")
    FileUtils.cp_r(%w[lib script].map { File.join(ROOT, it) }, @copy)
  end

  def teardown = FileUtils.rm_rf(@copy)

  def stamp(channel)
    _, status = Open3.capture2e(RbConfig.ruby, File.join(@copy, "script", "set_build_channel.rb"), *channel)
    [status.success?, File.read(File.join(@copy, "lib", "dot_popper", "build.rb"))]
  end

  def test_a_store_builds_channel_is_fixed_in_the_code
    ok, source = stamp("microsoft-store")

    assert ok
    assert_includes source, %(    CHANNEL = "microsoft-store"\n)
  end

  def test_an_unknown_or_missing_channel_changes_nothing
    [["steam"], []].each do |channel|
      ok, source = stamp(channel)

      refute ok, channel.inspect
      assert_includes source, "    CHANNEL = nil\n"
    end
  end

  def test_the_repositorys_own_build_is_a_test_build
    assert_nil DotPopper::Build::CHANNEL
  end
end
