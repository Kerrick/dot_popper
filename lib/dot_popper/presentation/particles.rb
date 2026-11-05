# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a burst of droplets looks: how many, how fast (radii a second),
    # how long each lives (seconds), how big (radii), how quickly the air
    # slows them, how hard they fall (radii a second squared), and how
    # opaque they start.
    class Burst < Data.define(:count, :speed, :life, :size, :drag, :gravity, :alpha)
      # The longest any droplet may live, so a burst never hides the dots
      # around it for long.
      LONGEST_LIFE = 0.45
    end

    # One droplet. Particles live in a ParticlePool and are reused, so a
    # burst on every tap makes no new objects.
    class Particle
      attr_reader :x, :y, :color

      def initialize
        @age = @life = 0.0
      end

      # Starts this particle afresh; it is alive until +life+ runs out.
      def launch(x:, y:, velocity_x:, velocity_y:, life:, size:, color:, drag:, gravity:, alpha:)
        @x = x
        @y = y
        @velocity_x = velocity_x
        @velocity_y = velocity_y
        @life = life
        @size = size
        @color = color
        @drag = drag
        @gravity = gravity
        @alpha = alpha
        @age = 0.0
        self
      end

      def alive? = @age < @life

      def update(seconds)
        return unless alive?

        @age += seconds
        slowing = Math.exp(-@drag * seconds)
        @velocity_x *= slowing
        @velocity_y = (@velocity_y * slowing) + (@gravity * seconds)
        @x += @velocity_x * seconds
        @y += @velocity_y * seconds
      end

      def progress = (@age / @life).clamp(0.0, 1.0)

      # It shrinks and fades as it goes.
      def size = @size * (1 - (0.55 * progress))
      def alpha = @alpha * (1 - Ease.in_quad(progress))

      def kill = @age = @life
    end

    # A fixed set of particles, reused in turn. When every one is alive,
    # the next launch takes the oldest, so the pool never grows.
    class ParticlePool
      include Enumerable

      attr_reader :capacity

      def initialize(capacity)
        @capacity = capacity
        @particles = Array.new(capacity) { Particle.new }
        @next = 0
      end

      def launch(**)
        particle = @particles[@next]
        @next = (@next + 1) % capacity
        particle.launch(**)
      end

      # Every live particle.
      def each
        @particles.each { |particle| yield particle if particle.alive? }
      end

      def update(seconds) = @particles.each { it.update(seconds) }
      def clear = @particles.each(&:kill)
    end
  end
end
