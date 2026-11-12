# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"

# Which tag releases what (script/release_kind.rb): the website builds for
# sale, or a playtest prerelease, never both.
class ReleaseKindTest < Minitest::Test
  SCRIPT = File.expand_path("../script/release_kind.rb", __dir__)

  def kind(tag)
    out, status = Open3.capture2(RbConfig.ruby, SCRIPT, tag)
    assert status.success?
    out.strip
  end

  def test_a_v0_tag_is_a_playtest_release_as_before
    %w[v0.9.9 v0.10.0 v0.8.2-rc.1].each { assert_equal "playtest", kind(it), it }
  end

  def test_a_release_from_1_0_0_on_sells_the_website_builds
    %w[v1.0.0 v1.2.3 v2.0.0 v1.0.0-rc.1].each { assert_equal "website", kind(it), it }
  end

  def test_anything_else_releases_nothing
    ["", "trunk", "v1", "v1.0", "1.0.0", "v1.0.0 ", "vx.1.0"].each { assert_equal "none", kind(it), it.inspect }
  end
end
