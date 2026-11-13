# frozen_string_literal: true

module DotPopperGui
  # Every theme's dots, drawn one at a time at the same place on its own
  # night and measured from screenshots (doc/design/look-and-sound.md,
  # "Contrast"):
  #
  # - Popped dots have no variants: popped dots 1, 2 and 3 do not differ
  #   in color, lightness or size, though a theme may vary their shape a
  #   little.
  # - Each dot is the same dot before and after its pop: whatever differs
  #   between two popped dots differs between them while bright too, so a
  #   popped dot's own details are the ones it had.
  # - Nothing in a popped dot is bright, or a player takes a piece of it
  #   for the bright dot.
  #
  # Needs DOT_POPPER_PRO=1.
  class PoppedDotsScenario < Scenario
    scenario :popped_dots

    D = DotPopper
    P = DotPopper::Presentation

    IDS = [1, 2, 3].freeze # each Jack-o'-lantern face, each Ghost's own hem

    # How far popped dots may differ: in size (the share of the drawn
    # area), in each channel of their mean color, and in lightness
    # (Shot#lightness, 0 to 1) at their middle and lightest hundredth.
    SIZE_SPREAD = 0.03
    COLOR_SPREAD = 0.02
    MIDDLE_SPREAD = 0.02
    LIGHTEST_SPREAD = 0.04

    # Two drawings differ at a point by more than this in lightness; a
    # point that differs between two popped dots must differ, within
    # NEAR points, between the same two dots bright, at least FOLLOWS of
    # the time.
    DIFFERS = 0.04
    NEAR = 2
    FOLLOWS = 0.9
    # Fewer differing points than this are a ghost's hem swaying with
    # time, not two dots that differ.
    SOME = 50

    # Themes whose dots are each subtly their own, and keep it through
    # their pop: Jack-o'-lantern's carved faces and Ghost's hems. Their
    # popped dots must still differ, or a dot lost its own at its pop.
    OWN_DOTS = %i[jack_o_lantern ghost].freeze

    # Lightness a popped dot's lightest hundredth, and its lightest
    # thousandth, may not pass. Jack-o'-lantern, Ghost and Eclipse, drawn
    # in dark tones, reach 0.17, 0.25 and 0.15 at the hundredth (Ghost's
    # eye holes and rim) and 0.21, 0.25 and 0.21 at the thousandth.
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
      drawn = P::Style::THEMES.map { draw(keeper, it) }
      drawn.each { alike(it) }
      say "ok - popped dots differ in no color, lightness or size"
      drawn.each { follows(it) }
      say "ok - each dot is the same dot before and after its pop"
      light = drawn.reject { dark?(it) }.map(&:key)
      fail!("too light when popped: #{(light - TOO_LIGHT).join(", ")}") unless (light - TOO_LIGHT).empty?
      say "ok - no popped dot is brighter than the shipped dark themes'"
      fail!("dark when popped now, so off the list: #{(TOO_LIGHT - light).join(", ")}") unless (TOO_LIGHT - light).empty?
      say "ok - every theme listed as too light still is"
    end

    private

    # One theme's night, then each dot bright and popped, one at a time,
    # in the middle of a game, as Patches.
    def draw(keeper, theme)
      keeper.use(theme)
      wait(0.5)
      check(show.in_use.key == theme.key, "#{theme.key} is in use")
      start_game
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 999))
      radius = game.field.radius # dots are drawn at the field's size
      x = layout.center_x
      y = layout.center_y
      shoot = lambda do |dots|
        game.instance_variable_set(:@dots, D::Stack.new(dots:))
        wait(0.3)
        Patch.new(screenshot, x, y, radius)
      end
      dot = ->(id, popped) { D::Dot.new(id:, x:, y:, velocity_x: 0, velocity_y: 0, radius:, popped:, bonus: false) }
      night = shoot.([])
      bright = IDS.map { shoot.([dot.(it, false)]) }
      popped = IDS.map { shoot.([dot.(it, true)]) }
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 0.01))
      run_out_the_clock
      continue_to_home
      Drawn.new(key: theme.key, night:, bright:, popped:)
    end

    def alike(drawn)
      sizes = drawn.popped.map { it.size_over(drawn.night) }
      colors = drawn.popped.map(&:mean_color)
      middles = drawn.popped.map { it.lightness(0.5) }
      lightest = drawn.popped.map { it.lightness(0.99) }
      say "#{drawn.key} popped: size #{sizes.join(", ")}; lightness #{(middles + lightest).map { format("%.3f", it) }.join(", ")}"
      fail!("#{drawn.key}'s popped dots differ in size") if spread(sizes) > SIZE_SPREAD * sizes.sum / sizes.size
      fail!("#{drawn.key}'s popped dots differ in color") if colors.transpose.any? { spread(it) > COLOR_SPREAD }
      fail!("#{drawn.key}'s popped dots differ in lightness") if spread(middles) > MIDDLE_SPREAD ||
                                                                 spread(lightest) > LIGHTEST_SPREAD
    end

    # Whatever differs between two popped dots differs between them while
    # bright, so a popped dot's details are the ones it had; and a theme
    # whose dots are their own keeps them popped.
    def follows(drawn)
      differ = IDS.each_index.to_a.combination(2).map do |a, b|
        popped = drawn.popped[a].differences(drawn.popped[b], DIFFERS)
        next false if popped.size < SOME

        bright = drawn.bright[a].differences(drawn.bright[b], DIFFERS).flat_map do |i, j|
          (-NEAR..NEAR).to_a.product((-NEAR..NEAR).to_a).map { |k, l| [i + k, j + l] }
        end.to_set
        near = popped.count { bright.include?(it) }
        say format("%s dots %d and %d: %d points differ popped, %.0f%% of them bright too", drawn.key, IDS[a], IDS[b],
                   popped.size, 100.0 * near / popped.size)
        fail!("#{drawn.key}'s popped dots #{IDS[a]} and #{IDS[b]} differ where they did not while bright") if near < FOLLOWS * popped.size
        true
      end
      fail!("#{drawn.key}'s popped dots are all alike, so a dot loses its own at its pop") if OWN_DOTS.include?(drawn.key) && !differ.all?
    end

    def dark?(drawn) = drawn.popped.all? do
      it.lightness(0.99, reach: 0.96) <= LIGHTEST_HUNDREDTH && it.lightness(0.999, reach: 0.96) <= LIGHTEST_THOUSANDTH
    end

    def spread(values) = values.max - values.min
  end

  # One theme's night, and its dots IDS bright and popped, as Patches.
  class Drawn < Data.define(:key, :night, :bright, :popped); end

  # The colors of a screenshot about a dot's center, in a square that
  # holds all the dot draws, its shadow and halo too, sampled every unit,
  # as Shot#color.
  class Patch
    def initialize(shot, x, y, radius)
      @radius = radius
      @half = (radius * 1.25).ceil
      @colors = (-@half..@half).map { |j| (-@half..@half).map { |i| shot.color(x + i, y + j) } }
    end

    # How many points the dot changes from +night+, the same place with
    # no dot.
    def size_over(night) = points.count { |i, j| changed?(color(i, j), night.color(i, j), 0.03) }

    # The mean color over the dot's middle, inside any outline a theme
    # gives it.
    def mean_color
      inner = points(0.8).map { color(*it) }
      (0..2).map { |c| inner.sum { it[c] } / inner.size }
    end

    # Lightness (Shot#lightness) at +share+ of the way from darkest to
    # lightest, within +reach+ radii of the center.
    def lightness(share, reach: 0.8)
      values = points(reach).map { lightness_of(color(*it)) }.sort
      values[(share * (values.size - 1)).round]
    end

    # The points where this and +other+ differ in lightness by more than
    # +by+.
    def differences(other, by) = points(1.05).select { |i, j| (lightness_of(color(i, j)) - lightness_of(other.color(i, j))).abs > by }

    def color(i, j) = @colors[j + @half][i + @half]

    private

    def points(reach = nil)
      all = (-@half..@half).to_a.product((-@half..@half).to_a)
      reach ? all.select { |i, j| Math.hypot(i, j) <= @radius * reach } : all
    end

    def changed?(one, other, by) = one.zip(other).any? { |a, b| (a - b).abs > by }

    def lightness_of(rgb) = (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2])
  end
end
