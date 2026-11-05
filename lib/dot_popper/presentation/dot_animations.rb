# frozen_string_literal: true

module DotPopper
  module Presentation
    # How dots move on top of their rule positions. Every motion here
    # scales a dot about its own centre and never moves the centre, so a
    # dot is always drawn where a tap reaches it.
    #
    # +spawn+ scales a new dot in from a seed; +pop_stretch+ is the width
    # of a just-popped dot as it squashes and springs back (its height is
    # the inverse, so it keeps its volume); +pop_cover+ is how much of the
    # fresh look still shows over the popped one; +wobble+ is the
    # "wrong!" shudder; +breathe+ the idle swell of a fresh dot.
    class DotMotion < Data.define(:spawn, :pop_stretch, :pop_cover, :wobble, :breathe); end

    # A shudder: how far it squashes at first (a fraction of the radius),
    # how long it lasts, and how many times a second it shakes.
    class Wobble < Data.define(:amplitude, :duration, :frequency)
      def at(elapsed)
        return 0.0 if elapsed >= duration

        amplitude * ((1 - (elapsed / duration))**2) * Math.sin(elapsed * frequency * 2 * Math::PI)
      end

      def glow(elapsed) = elapsed >= duration ? 0.0 : 1 - (elapsed / duration)
    end

    # A slow swell: how much bigger at its fullest (a fraction), and how
    # many seconds one breath takes.
    class Breathe < Data.define(:amplitude, :period)
      def at(time, phase) = 1 + (amplitude * Math.sin(((time / period) + phase) * 2 * Math::PI))
    end

    # How to draw one dot at one moment: its scale across and down, how
    # much of its fresh look still shows (1 for a fresh dot, 0 once a
    # popped dot has finished changing), and how strongly its rim glows
    # from a wrong tap.
    class Pose < Data.define(:scale_x, :scale_y, :freshness, :alarm)
      STILL = new(scale_x: 1.0, scale_y: 1.0, freshness: 0.0, alarm: 0.0)
    end

    # When each dot was born, popped, and tapped by mistake, kept by dot
    # id, since a dot is a new value every frame. A dot with no record is
    # simply at rest.
    class DotAnimations
      # When one dot was born, popped, and tapped by mistake; nil for what
      # has not happened to it.
      class Moments < Data.define(:born, :popped, :wobbled)
        NONE = new(born: nil, popped: nil, wobbled: nil)
      end

      def initialize(motion)
        @motion = motion
        @records = {}
      end

      def spawn(id, now) = note(id, born: now)
      def pop(id, now) = note(id, popped: now)
      def wobble(id, now) = note(id, wobbled: now)

      def clear = @records.clear
      def size = @records.size

      def pose(dot, now)
        found = @records[dot.id]
        breath = dot.fresh? ? @motion.breathe.at(now, phase(dot.id)) : 1.0
        return still(dot, breath) unless found

        scale = found.born ? @motion.spawn.at(now - found.born) : 1.0
        stretch_x, stretch_y = stretch(found, now)
        wobble = found.wobbled ? @motion.wobble.at(now - found.wobbled) : 0.0
        Pose.new(scale_x: scale * breath * stretch_x * (1 + wobble), scale_y: scale * breath * stretch_y * (1 - wobble),
                 freshness: freshness(dot, found, now), alarm: found.wobbled ? @motion.wobble.glow(now - found.wobbled) : 0.0)
      end

      private

      def note(id, **moment) = @records[id] = @records.fetch(id, Moments::NONE).with(**moment)

      def still(dot, breath)
        return Pose::STILL if dot.popped?

        Pose.new(scale_x: breath, scale_y: breath, freshness: 1.0, alarm: 0.0)
      end

      def stretch(found, now)
        return [1.0, 1.0] unless found.popped

        across = @motion.pop_stretch.at(now - found.popped)
        [across, 1 / across]
      end

      def freshness(dot, found, now)
        return 1.0 if dot.fresh?
        return 0.0 unless found.popped

        @motion.pop_cover.at(now - found.popped).clamp(0.0, 1.0)
      end

      # Each dot breathes a little out of step with the others.
      def phase(id) = ((id * 0.618034) % 1.0)
    end
  end
end
