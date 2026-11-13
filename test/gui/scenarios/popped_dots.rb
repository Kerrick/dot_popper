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
  # - No piece of a popped dot looks like the bright dot at a glance, or
  #   a player takes it for a piece of the bright dot (Glance).
  # - A dot drawn twice at the same moment of the game, with real time
  #   between, looks the same, so no screenshot here depends on how fast
  #   the machine draws.
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
    # Real seconds between two drawings of the same moment of the game.
    PAUSE = 0.25

    # Themes whose dots are each subtly their own, and keep it through
    # their pop: Jack-o'-lantern's carved faces and Ghost's hems. Their
    # popped dots must still differ, or a dot lost its own at its pop.
    OWN_DOTS = %i[jack_o_lantern ghost].freeze

    # How near, at the least, a popped dot's colors may come to the
    # bright dot's (Glance.nearest, CIELAB distance). Classic,
    # Jack-o'-lantern, Ghost and Eclipse, which read at a glance, keep
    # 60.0, 56.4, 72.8 and 84.0 away; the Santa a playtester could not
    # tell from the bright one when popped (the shader before 79ca5ae)
    # came within 31.0, his eyes' pale glints against the bright Santa's
    # white beard.
    NEAREST = 45

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
      say "ok - no dot moves with the time on the wall"
      near = drawn.select { nearest(it) < NEAREST }.map(&:key)
      fail!("popped dots too near the bright one: #{near.join(", ")}") unless near.empty?
      say "ok - no popped dot comes near the bright one"
    end

    private

    # One theme's night, then each dot bright and popped, one at a time,
    # in the middle of a game, as Patches.
    def draw(keeper, theme)
      show.instance_variable_get(:@use_theme).call(theme)
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
      still(theme, x, y, radius)
      popped = IDS.map { shoot.([dot.(it, true)]) }
      game.instance_variable_set(:@countdown, D::Countdown.new(remaining: 0.01))
      run_out_the_clock
      continue_to_home
      Drawn.new(key: theme.key, night:, bright:, popped:)
    end

    # The bright dot drawn twice at the same moment of the game, PAUSE
    # seconds of real time apart, looks the same: nothing a dot draws
    # moves with the time on the wall, so how fast a machine draws changes
    # no screenshot (a theme's shader once took its time from Lota::Timer,
    # and Ghost's hem swayed between these checks' screenshots).
    def still(theme, x, y, radius)
      first = Patch.new(screenshot(step: 0.0), x, y, radius)
      sleep(PAUSE)
      changed = first.differences(Patch.new(screenshot(step: 0.0), x, y, radius), DIFFERS).size
      fail!("#{theme.key}'s dot changes with the time on the wall (#{changed} points)") unless changed.zero?
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

    # The nearest each popped dot comes to the same dot bright.
    def nearest(drawn)
      distance = drawn.popped.zip(drawn.bright).map { |popped, bright| Glance.nearest(popped, bright) }.min
      say format("%s popped comes within %.1f of the bright dot", drawn.key, distance)
      distance
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

    # The CIELAB colors (Glance.lab) of the points within +reach+ radii.
    def labs(reach = 0.9) = points(reach).map { Glance.lab(color(*it)) }

    private

    def points(reach = nil)
      all = (-@half..@half).to_a.product((-@half..@half).to_a)
      reach ? all.select { |i, j| Math.hypot(i, j) <= @radius * reach } : all
    end

    def changed?(one, other, by) = one.zip(other).any? { |a, b| (a - b).abs > by }

    def lightness_of(rgb) = (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2])
  end

  # How near a popped dot comes to looking like the bright dot, as a
  # player sees them at a glance in a crowd: the eye finds the bright dot
  # by its color, and what shows of a covered one is a sliver, often less
  # than a third of it. So the bright dot is taken as its lightest SLIVER
  # of points, the colors a sliver of it shows at its lightest, and a popped
  # dot by its CLOSEST share of points nearest those colors, as a small
  # pale glint is enough to take for the bright dot. The distance is in
  # CIELAB (CIE 1976), where equal steps look about equally far apart in
  # lightness and in color, so a popped dot as light as Classic's lilac rim
  # is far from a gold bright dot, and a pale gray glint is near a white
  # one.
  module Glance
    SLIVER = 0.3
    CLOSEST = 0.001
    STEP = 2.0 # colors are rounded to this many units, to be quick

    def self.nearest(popped, bright)
      light = bright.labs.sort_by(&:first)
      targets = light.last((light.size * SLIVER).ceil).map { round(it) }.uniq.sort
      distances = popped.labs.map { round(it) }.tally.flat_map { |color, count| [closest(color, targets)] * count }.sort
      distances[(CLOSEST * (distances.size - 1)).round]
    end

    # [L*, a*, b*] of an sRGB color, each channel from 0 to 1, under D65.
    def self.lab(rgb)
      r, g, b = rgb.map { it <= 0.04045 ? it / 12.92 : ((it + 0.055) / 1.055)**2.4 }
      x = f(((0.4124 * r) + (0.3576 * g) + (0.1805 * b)) / 0.95047)
      y = f((0.2126 * r) + (0.7152 * g) + (0.0722 * b))
      z = f(((0.0193 * r) + (0.1192 * g) + (0.9505 * b)) / 1.08883)
      [(116 * y) - 16, 500 * (x - y), 200 * (y - z)]
    end

    def self.f(t) = t > 0.008856 ? t**(1 / 3.0) : (7.787 * t) + (16 / 116.0)

    def self.round(lab) = lab.map { (it / STEP).round * STEP }

    # The distance from +color+ to the nearest of +targets+, sorted by
    # lightness: none farther in lightness alone than the nearest so far
    # can be nearer.
    def self.closest(color, targets)
      start = targets.bsearch_index { it[0] >= color[0] } || targets.size
      nearest = Float::INFINITY
      [(start...targets.size), (start - 1).downto(0)].each do |indices|
        indices.each do |i|
          target = targets[i]
          break if (target[0] - color[0]).abs >= nearest

          nearest = [nearest, Math.sqrt(color.zip(target).sum { |a, b| (a - b)**2 })].min
        end
      end
      nearest
    end
  end
end
