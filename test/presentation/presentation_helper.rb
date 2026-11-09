# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"

module PresentationTest
  include DotPopperTest
  include DotPopper::Presentation

  Style = DotPopper::Presentation::Style

  # Sounds that only remember what they were asked to play.
  class FakeSounds
    attr_reader :played, :pans

    def initialize = (@played = []) && (@pans = []) && (@muted = false)

    def play(name, pitch: 1.0, pan: 0.0)
      @played << [name, pitch]
      @pans << pan
    end

    def muted? = @muted
    def toggle_mute = @muted = !@muted
    def names = played.map(&:first)
  end

  # A desktop's window that only remembers what it was asked: whether it
  # is fullscreen, and how many times it was asked to quit.
  class FakeWindow
    attr_reader :quits

    attr_accessor :display

    def initialize = (@display = :window) && (@quits = 0)

    def offered? = true
    def fullscreen? = display != :window
    def toggle_fullscreen = self.display = fullscreen? ? :window : :borderless
    def quit = @quits += 1
  end

  # Haptics that only remember how long each buzz was.
  class FakeHaptics
    attr_reader :buzzes

    def initialize = @buzzes = []
    def buzz(seconds) = @buzzes << seconds
  end

  # Presses the main button of the screen +show+ is on: Play on the
  # title, or Continue on Game Over.
  def press_main(show = @show)
    reach = show.play_reach || show.continue_reach
    show.tap(reach.center_x, reach.center_y)
  end

  def layout(width = 800, height = 600)
    Layout.new(width:, height:, safe: Rect.new(x: 0, y: 0, width:, height:), style: Style::LAYOUT)
  end
end
