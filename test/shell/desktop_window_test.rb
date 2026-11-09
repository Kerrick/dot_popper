# frozen_string_literal: true

require "test_helper"
require "dot_popper/shell/desktop_window"

# DesktopWindow moves the window as Settings' Display choice and F11 ask,
# through Lota's Window, here a stand-in that remembers what it was told.
class DesktopWindowTest < Minitest::Test
  class FakeWindow
    def initialize = @state = [false, :desktop]
    def fullscreen = @state
    def set_fullscreen(on, type) = @state = [on, type]
  end

  def test_each_display_choice_moves_the_window_and_reads_back
    lota = FakeWindow.new
    window = DotPopper::Shell::DesktopWindow.new(lota:)

    %i[borderless exclusive window].each do |mode|
      window.display = mode
      assert_equal mode, window.display
    end
  end

  def test_f11_goes_back_to_the_last_fullscreen_choice
    lota = FakeWindow.new
    window = DotPopper::Shell::DesktopWindow.new(lota:)

    window.display = :exclusive
    window.display = :window
    window.toggle_fullscreen
    assert_equal :exclusive, window.display

    window.toggle_fullscreen
    assert_equal :window, window.display
  end

  def test_f11_with_no_choice_yet_is_borderless_unless_asked_for_exclusive
    plain = DotPopper::Shell::DesktopWindow.new(lota: FakeWindow.new)
    plain.toggle_fullscreen
    assert_equal :borderless, plain.display

    exclusive = DotPopper::Shell::DesktopWindow.new(exclusive: true, lota: FakeWindow.new)
    exclusive.toggle_fullscreen
    assert_equal :exclusive, exclusive.display
  end
end
