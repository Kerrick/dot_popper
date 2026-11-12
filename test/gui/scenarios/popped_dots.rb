# frozen_string_literal: true

module DotPopperGui
  # Every theme's popped dot, drawn alone on its own night and measured
  # from a screenshot: nothing in a popped dot may be bright, or a player
  # takes a piece of it for the bright dot. A popped dot reads by its
  # shape in dark tones (doc/design/look-and-sound.md, "Contrast"). Needs
  # DOT_POPPER_PRO=1.
  class PoppedDotsScenario < Scenario
    scenario :popped_dots

    D = DotPopper
    P = DotPopper::Presentation

    # Lightness (Shot#lightness, 0 to 1) a popped dot's lightest
    # hundredth, and its lightest thousandth, may not pass. Jack-o'-lantern,
    # Ghost and Eclipse, drawn in dark tones, reach 0.17, 0.25 and 0.15 at
    # the hundredth (Ghost's eye holes and rim) and 0.21, 0.25 and 0.21 at
    # the thousandth.
    LIGHTEST_HUNDREDTH = 0.26
    LIGHTEST_THOUSANDTH = 0.3

    # Themes whose popped dots are known to be too light, until each is
    # redrawn. Each must still fail, so the list cannot go stale.
    TOO_LIGHT = %i[classic awake jingle_bell].freeze

    def play
      keeper = show.instance_variable_get(:@theme_keeper)
      wait(0.5)
      keeper.receive(P::Style::THEMES.map(&:key))
      keeper.told(keeper.arrival) until keeper.arrival.nil?
      light = P::Style::THEMES.reject { dark?(measure(keeper, it)) }.map(&:key)
      fail!("too light when popped: #{(light - TOO_LIGHT).join(", ")}") unless (light - TOO_LIGHT).empty?
      say "ok - no popped dot is brighter than the shipped dark themes'"
      fail!("dark when popped now, so off the list: #{(TOO_LIGHT - light).join(", ")}") unless (TOO_LIGHT - light).empty?
      say "ok - every theme listed as too light still is"
    end

    private

    def measure(keeper, theme)
      keeper.use(theme)
      wait(0.5)
      check(show.in_use.key == theme.key, "#{theme.key} is in use")
      start_game
      radius = game.field.radius # dots are drawn at the field's size
      x = layout.center_x
      y = layout.center_y
      dot = D::Dot.new(id: 1, x:, y:, velocity_x: 0, velocity_y: 0, radius:, popped: true, bonus: false)
      game.instance_variable_set(:@dots, D::Stack.new(dots: [dot]))
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 999))
      wait(1.0)
      lightness = Lightness.new(screenshot, x, y, radius)
      say "#{theme.key} popped: #{lightness}"
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 0.01))
      run_out_the_clock
      continue_to_home
      lightness
    end

    def dark?(lightness) = lightness.percentile(0.99) <= LIGHTEST_HUNDREDTH &&
                           lightness.percentile(0.999) <= LIGHTEST_THOUSANDTH
  end

  # The lightness over a popped dot's disc, inside its antialiased edge,
  # sampled every unit, as Shot#lightness (0 to 1).
  class Lightness
    def initialize(shot, x, y, radius)
      reach = radius * 0.96
      @values = []
      (-reach.floor..reach.floor).each do |i|
        (-reach.floor..reach.floor).each do |j|
          @values << shot.lightness(x + i, y + j) if Math.hypot(i, j) <= reach
        end
      end
      @values.sort!
    end

    def percentile(share) = @values[(share * (@values.size - 1)).round]

    def to_s = format("half %.3f, lightest hundredth %.3f, lightest thousandth %.3f, %d points",
                      percentile(0.5), percentile(0.99), percentile(0.999), @values.size)
  end
end
