# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "rbconfig"

# A release for a store fails while an identifier that store needs is
# missing or a stand-in (script/check_store_identifiers.rb); a release for
# another channel never waits on it.
class StoreIdentifiersTest < Minitest::Test
  SCRIPT = File.expand_path("../script/check_store_identifiers.rb", __dir__)
  SET = { "MSIX_IDENTITY_NAME" => "12345setdef.DotPopper", "MSIX_PUBLISHER" => "CN=0A1B2C3D-0000-1111-2222-333344445555",
          "APPLE_TEAM_ID" => "ABCDE12345" }.freeze
  UNSET = SET.keys.to_h { [it, nil] }.freeze

  def check(channel, env)
    _, status = Open3.capture2e(UNSET.merge(env), RbConfig.ruby, SCRIPT, *channel)
    status.success?
  end

  def test_every_identifier_set_passes_for_every_channel
    DotPopper::Build::CHANNEL_NAMES.each { assert check(it, SET), it }
  end

  def test_the_microsoft_store_needs_its_package_identity
    %w[MSIX_IDENTITY_NAME MSIX_PUBLISHER].each { refute check("microsoft-store", SET.merge(it => "")), it }
    refute check("microsoft-store", SET.merge("MSIX_IDENTITY_NAME" => "setdef.DotPopper"))
    refute check("microsoft-store", SET.merge("MSIX_PUBLISHER" => "CN=Dot Popper test"))
    assert check("microsoft-store", SET.merge("APPLE_TEAM_ID" => ""))
  end

  def test_apples_stores_need_the_team_id
    %w[mac-app-store app-store].each do |channel|
      refute check(channel, SET.merge("APPLE_TEAM_ID" => "")), channel
      refute check(channel, SET.merge("APPLE_TEAM_ID" => "team")), channel
      assert check(channel, SET.merge("MSIX_IDENTITY_NAME" => "")), channel
    end
  end

  def test_the_website_and_google_play_need_none
    %w[website google-play].each { assert check(it, {}), it }
  end

  def test_an_unknown_or_missing_channel_fails
    refute check("steam", SET)
    refute check([], SET)
  end
end
