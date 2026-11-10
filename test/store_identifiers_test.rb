# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"

# A v1* tag fails while a store's identifier is missing or a stand-in
# (script/check_store_identifiers.rb, run by release-channel.yml).
class StoreIdentifiersTest < Minitest::Test
  SCRIPT = File.expand_path("../script/check_store_identifiers.rb", __dir__)
  SET = { "MSIX_IDENTITY_NAME" => "12345setdef.DotPopper", "MSIX_PUBLISHER" => "CN=0A1B2C3D-0000-1111-2222-333344445555",
          "APPLE_TEAM_ID" => "ABCDE12345" }.freeze

  def check(env)
    _, status = Open3.capture2e(SET.keys.to_h { [it, nil] }.merge(env), RbConfig.ruby, SCRIPT)
    status.success?
  end

  def test_every_identifier_set_passes
    assert check(SET)
  end

  def test_a_missing_or_stand_in_identifier_fails
    SET.each_key { refute check(SET.merge(it => "")), it }
    refute check(SET.merge("MSIX_IDENTITY_NAME" => "setdef.DotPopper"))
    refute check(SET.merge("MSIX_PUBLISHER" => "CN=Dot Popper test"))
    refute check(SET.merge("APPLE_TEAM_ID" => "team"))
  end
end
