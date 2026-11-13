# frozen_string_literal: true

module DotPopperGui
  # One theme's pictures to judge it by, from the real game: the title on a
  # desktop window and an upright phone; a close-up of a bright, a popped
  # and a bonus dot, and a bright dot under a popped one; and a crowded
  # game on each, caught when the bright dot is mostly covered.
  # DOT_POPPER_THEME names the theme; DOT_POPPER_SEED makes every theme
  # play the same game, so their frames compare. Not part of rake
  # test:gui: it is for reviewing themes.
  class HolidayGalleryScenario < Scenario
    scenario :holiday_gallery

    P = DotPopper::Presentation
    D = DotPopper

    def play
      @theme = ENV.fetch("DOT_POPPER_THEME", "classic")
      keeper = show.instance_variable_get(:@theme_keeper)
      wait(0.5)
      keeper.told(keeper.arrival) until keeper.arrival.nil?
      fit(1200, 800, false)
      wait(1.5)
      keep_screenshot("#{@theme}-title-desktop")
      closeup
      crowd("desktop", 44)
      fit(400, 850, true)
      wait(1.5)
      keep_screenshot("#{@theme}-title-phone")
      crowd("phone", 34)
    end

    private

    def fit(width, height, phone)
      show.instance_variable_set(:@window, P::NoWindowControl.new) if phone
      # The window manager may change the window after it opens, so the
      # size is asked for again until it holds.
      4.times do
        resize(width, height) unless L::Graphics.dimensions == [width, height]
        frames(30, step: 0.0)
      end
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
    end

    def still(id, x, y, radius, popped: false, bonus: false)
      D::Dot.new(id:, x:, y:, velocity_x: 0, velocity_y: 0, radius:, popped:, bonus:)
    end

    # Four still dots, large: bright, popped, bonus, and a bright one
    # under a popped one.
    def closeup
      r = cabinet.field.radius
      x = layout.center_x - (r * 5)
      y = layout.center_y
      dots = [still(5, x + (r * 7.9), y - (r * 0.7), r, popped: true), still(1, x, y, r), still(2, x + (r * 2.6), y, r, popped: true),
              still(3, x + (r * 5.2), y, r, bonus: true), still(4, x + (r * 7.2), y, r)]
      start_game
      game.instance_variable_set(:@dots, D::Stack.new(dots:))
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 999))
      wait(1.5)
      keep_screenshot("#{@theme}-closeup")
      finish
    end

    def finish
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 0.01))
      run_out_the_clock
      wait(2.5)
      keep_screenshot("#{@theme}-over-#{@size_tag}") if @size_tag
      continue_to_home
    end

    def crowd(tag, count)
      @size_tag = tag
      start_game
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 999))
      pop_bright while game.dots.size < count
      shown = nil
      2400.times do
        bright = bright_dot
        share = showing(bright)
        if inside_window?(bright) && share.between?(0.12, 0.3)
          shown = share
          break
        end
        frames
      end
      say "#{@theme} #{tag}: #{game.dots.size} dots, the bright dot #{((shown || showing(bright_dot)) * 100).round}% showing"
      keep_screenshot("#{@theme}-crowd-#{tag}")
      finish
    end

    # How much of +dot+ is on top, sampled on a grid.
    def showing(dot)
      inside = 0
      top = 0
      (-10..10).each do |i|
        (-10..10).each do |j|
          x = dot.x + (dot.radius * i / 10.0)
          y = dot.y + (dot.radius * j / 10.0)
          next unless dot.covers?(x, y)

          inside += 1
          top += 1 if game.dots.top_at(x, y)&.id == dot.id
        end
      end
      top.to_f / inside
    end
  end
end
