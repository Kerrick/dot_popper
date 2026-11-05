# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a burst of droplets looks: how many, how fast (radii a second),
    # how long each lives (seconds), how big (radii), how quickly the air
    # slows them, how hard they fall (radii a second squared), how opaque
    # they start, how fast they turn (radians a second, start to end), and
    # which sprite they are (SpriteArt). LÖVE's ParticleSystem flies them
    # (Shell::Sparks); Emission turns this into its settings.
    class Burst < Data.define(:count, :speed, :life, :size, :drag, :gravity, :alpha, :spin, :sprite)
      # The longest any droplet may live, so a burst never hides the dots
      # around it for long.
      LONGEST_LIFE = 0.45

      def initialize(count:, speed:, life:, size:, drag:, gravity:, alpha:, spin: 0.0..0.0, sprite: :droplet) = super

      # How many of +count+ droplets each of +colors+ gets: an even share,
      # and the rest to colors picked at random.
      def shares(colors, random)
        each, rest = count.divmod(colors.size)
        lucky = colors.sample(rest, random:)
        colors.to_h { [it, each + (lucky.include?(it) ? 1 : 0)] }
      end
    end

    # A burst asked for at (+x+, +y+), waiting for the shell to throw it:
    # its look, its colors, the longest a droplet of it may live, and the
    # +radius+ of the dots it is for, which its sizes are measured in.
    class Spray < Data.define(:x, :y, :look, :colors, :longest, :radius)
      def emission(sprite_size) = Emission.new(look:, longest:, radius:, sprite_size:)
    end

    # A Burst as a ParticleSystem's settings, in graphics units, for dots
    # of +radius+ and a sprite +sprite_size+ units across.
    class Emission < Data.define(:look, :longest, :radius, :sprite_size)
      # A droplet shrinks to this much of its first size as it goes.
      SHRINK = 0.45

      def lifetime = [[look.life.begin, longest].min, [look.life.end, longest].min]
      def speed = [look.speed.begin * radius, look.speed.end * radius]
      def damping = [look.drag, look.drag]
      def acceleration = [0.0, look.gravity * radius, 0.0, look.gravity * radius]
      def spin = [look.spin.begin, look.spin.end]

      # The sprite's scale at the start and end of a droplet's life, for
      # the largest droplet; a Burst's size is a droplet's radius.
      def sizes
        largest = 2 * look.size.end * radius / sprite_size
        [largest, largest * SHRINK]
      end

      # How far toward its end size a droplet may start, so the smallest
      # starts at the Burst's smallest size (LÖVE's size variation).
      def size_variation = ((1 - (look.size.begin / look.size.end)) / (1 - SHRINK)).clamp(0.0, 1.0)

      # One color's fade, as LÖVE's colors through a particle's life: it
      # holds most of its opacity through the middle, then goes.
      def colors(color)
        [1.0, 0.75, 0.0].map { [color.r, color.g, color.b, look.alpha * it] }
      end
    end

    # The particles' sprites, drawn in code: each is an opacity at a point
    # (+x+, +y+) from -1 to 1 across the sprite, white everywhere else.
    module SpriteArt
      module_function

      # A soft round droplet, brightest in the middle.
      def droplet(x, y) = 1.0 - smoothstep(0.3, 1.0, Math.hypot(x, y))

      # A twinkle: a soft core with four thin rays, so its spin shows.
      def twinkle(x, y)
        core = 1.0 - smoothstep(0.0, 0.45, Math.hypot(x, y))
        rays = [x.abs, y.abs].minmax.then { |thin, long| (1.0 - smoothstep(0.0, 0.12, thin)) * (1.0 - long) }
        [core + rays, 1.0].min
      end

      def smoothstep(low, high, value)
        t = ((value - low) / (high - low)).clamp(0.0, 1.0)
        t * t * (3 - (2 * t))
      end

      # The opacity of +sprite+ at pixel (+column+, +row+) of a square
      # +pixels+ wide, sampled at the pixel's centre.
      def alpha(sprite, column, row, pixels)
        across = ((column + 0.5) / pixels * 2) - 1
        down = ((row + 0.5) / pixels * 2) - 1
        public_send(sprite, across, down).clamp(0.0, 1.0)
      end
    end
  end
end
