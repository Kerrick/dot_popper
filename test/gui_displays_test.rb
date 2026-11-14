# frozen_string_literal: true

require "test_helper"
require_relative "gui/displays"

# How many GUI scenarios play at once (test/gui/displays.rb): several
# only where each can have a display of its own, on Linux under X with
# Xvfb and Openbox at hand; one after another anywhere else. Nothing here
# starts a display.
class GuiDisplaysTest < Minitest::Test
  Displays = DotPopperGui::Displays
  LINUX = "x86_64-linux"
  X = { "DISPLAY" => ":99" }.freeze
  BOTH = ->(_) { true }

  def test_several_at_once_where_displays_can_be_started
    assert_equal Etc.nprocessors.clamp(1, Displays::MOST), workers(X)
    assert_equal 3, workers(X.merge("DOT_POPPER_GUI_WORKERS" => "3"))
    assert_equal 1, workers(X.merge("DOT_POPPER_GUI_WORKERS" => "0"))
  end

  def test_one_at_a_time_without_a_display_xvfb_or_openbox
    asked = { "DOT_POPPER_GUI_WORKERS" => "4" }
    assert_equal 1, workers(asked)
    assert_equal 1, workers(asked.merge("DISPLAY" => ""))
    assert_equal 1, workers(X.merge(asked), found: ->(program) { program == "Xvfb" })
    assert_equal 1, workers(X.merge(asked), found: ->(program) { program == "openbox" })
  end

  def test_one_at_a_time_on_macos_and_windows
    %w[arm64-darwin x64-mingw-ucrt].each { assert_equal 1, workers(X, platform: it) }
  end

  private

  def workers(env, platform: LINUX, found: BOTH) = Displays.workers(env, platform:, found:)
end
