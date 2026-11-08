# frozen_string_literal: true

require "test_helper"

# Dot Popper's Android manifest (android/host). SDL ends the app when
# Android makes its activity again, so the activity must handle each
# configuration change a player or the system can make while the game
# runs. Density is left out, as in SDL's own manifest, since it sets the
# game's sizes.
class AndroidManifestTest < Minitest::Test
  MANIFEST = File.read(File.expand_path("../android/host/src/main/AndroidManifest.xml", __dir__))
  HANDLED = MANIFEST[/android:configChanges="([^"]*)"/, 1].to_s.split("|")

  def test_the_activity_keeps_running_through_a_turn_or_a_keyboard
    assert_empty %w[orientation screenSize smallestScreenSize screenLayout keyboard keyboardHidden navigation] - HANDLED
  end

  def test_the_activity_keeps_running_through_dark_theme_font_size_and_language
    assert_empty %w[uiMode fontScale fontWeightAdjustment locale layoutDirection grammaticalGender] - HANDLED
  end

  def test_the_activity_keeps_running_through_an_overlay_or_a_sim
    assert_empty %w[assetsPaths mcc mnc touchscreen colorMode] - HANDLED
  end

  def test_sdl_still_traps_back
    assert_includes MANIFEST, '<meta-data android:name="SDL_ENV.SDL_ANDROID_TRAP_BACK_BUTTON" android:value="1" />'
  end
end
