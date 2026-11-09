# frozen_string_literal: true

module DotPopper
  module Presentation
    # How dragging the game-over pile feels, in radii and seconds, so it
    # feels alike at any dot size. A press on a ball becomes a drag once
    # it wanders more than +slop+ radii from where it went down, or is
    # held for +hold+ seconds; until then it may still be a click. A
    # dragged ball closes on the pointer in about +follow+ seconds, never
    # faster than +fastest+ radii a second, and when it is let go it
    # keeps the pointer's speed over its last +window+ seconds, up to
    # +fling+ radii a second.
    class GrabLook < Data.define(:slop, :hold, :follow, :fastest, :fling, :window); end

    # Where a pointer was, and when.
    class Sample < Data.define(:x, :y, :at); end

    # A dragged ball let go: +ball+ is its dot's id, and +velocity+ the
    # [x, y] it flies off with, in graphics units a second, or nil to keep
    # the speed it has.
    class Fling < Data.define(:ball, :velocity); end

    # A press and release that was a click, heard as a press: on Game
    # Over, the tap that goes back to the title.
    class Click < Data.define(:x, :y); end

    # One pointer's press on Game Over, from the moment it goes down. It
    # went down on +ball+ (a dot's id, or nil for none) with the ball's
    # middle +offset+ from the pointer, as [x, y]; +heard+ says whether
    # the game would have heard a press then (Cabinet::GameOver#ready?). +samples+ are where
    # the pointer has been lately, newest last. Once +wandered+ past the
    # slop, it is no click; once +dragging+, it holds its ball.
    class Grab < Data.define(:ball, :offset, :radius, :heard, :start, :samples, :wandered, :dragging)
      def self.press(x, y, at:, radius:, heard:, ball: nil, center: nil)
        offset = center ? [center[0] - x, center[1] - y] : [0.0, 0.0]
        sample = Sample.new(x: x.to_f, y: y.to_f, at:)
        new(ball:, offset:, radius:, heard:, start: sample, samples: [sample], wandered: false, dragging: false)
      end

      # The grab with the pointer moved to +x+, +y+ at +at+.
      def moved(x, y, at, look)
        sample = Sample.new(x: x.to_f, y: y.to_f, at:)
        far = Math.hypot(sample.x - start.x, sample.y - start.y) > look.slop * radius
        kept = samples.drop_while.with_index { |old, i| i < samples.size - 1 && samples[i + 1].at <= at - look.window }
        with(samples: kept + [sample], wandered: wandered || far).promoted(at, look)
      end

      # The grab at +at+, a drag once it has wandered or been held long
      # enough on a ball.
      def promoted(at, look)
        return self if dragging || ball.nil?

        with(dragging: wandered || at - start.at >= look.hold)
      end

      # Whether letting go now is a click: never once it has dragged or
      # wandered.
      def click? = !dragging && !wandered

      def pointer = samples.last

      # Where the ball's middle should be: under the pointer as it was
      # first held.
      def target = [pointer.x + offset[0], pointer.y + offset[1]]

      # The velocity that brings a ball's middle at +center+ to its target,
      # in graphics units a second.
      def pull(center, look)
        tx, ty = target
        capped([(tx - center[0]) / look.follow, (ty - center[1]) / look.follow], look.fastest * radius)
      end

      # The pointer's velocity as it lets go at +at+, over its last
      # samples, no faster than the look's fling.
      def throw_velocity(at, look)
        first = samples.first
        last = pointer
        seconds = [at - first.at, 1e-3].max
        seconds = [seconds, look.window].max if samples.size == 1
        capped([(last.x - first.x) / seconds, (last.y - first.y) / seconds], look.fling * radius)
      end

      private

      def capped(velocity, most)
        speed = Math.hypot(*velocity)
        speed > most ? velocity.map { it * most / speed } : velocity
      end
    end

    # Every pointer pressed on Game Over, by a key of its own: :mouse, or
    # a touch's id. It decides, apart from Lota, what each press is: a
    # click that goes on, as a press did before there was a pile to play
    # with, or a drag that holds a ball and throws it when let go. A
    # pointer that wanders without a ball does nothing, and no click goes
    # on while another pointer is dragging, so a drag never leaves Game
    # Over. A ball held by one pointer cannot be taken by another.
    class PileGrabs
      def initialize(look)
        @look = look
        @grabs = {}
      end

      # A pointer went down at +x+, +y+ at +now+, on +ball+ whose middle is
      # at +center+, or on no ball. A pointer pressed again before it was
      # let go, as iOS may cancel a touch without saying, lets its ball go
      # first; the Fling, if any, is returned.
      def press(key, x, y, now:, radius:, heard:, ball: nil, center: nil)
        dropped = drop(key)
        ball = center = nil if ball && holding?(ball)
        @grabs[key] = Grab.press(x, y, at: now, radius:, heard:, ball:, center:)
        dropped
      end

      def move(key, x, y, now:)
        grab = @grabs[key] or return
        @grabs[key] = grab.moved(x, y, now, @look)
      end

      # Turns holds long enough into drags.
      def update(now) = @grabs.transform_values! { it.promoted(now, @look) }

      # The pointer let go at +x+, +y+: a Fling for a drag, a Click for a
      # click the game would hear, or nil.
      def release(key, x, y, now:)
        grab = @grabs.delete(key) or return
        grab = grab.moved(x, y, now, @look)
        return Fling.new(ball: grab.ball, velocity: grab.throw_velocity(now, @look)) if grab.dragging
        return unless grab.click? && grab.heard && @grabs.none? { |_, other| other.dragging }

        Click.new(x: x.to_f, y: y.to_f)
      end

      # Forgets every pointer, as when the window loses focus or the pile
      # goes: each dragged ball is let go with the speed it has.
      def drop_all = @grabs.keys.filter_map { drop(it) }

      # Each pointer dragging a ball, as its Grab.
      def drags = @grabs.values.select(&:dragging)

      def holding?(ball) = @grabs.any? { |_, grab| grab.ball == ball }

      private

      def drop(key)
        grab = @grabs.delete(key)
        Fling.new(ball: grab.ball, velocity: nil) if grab&.dragging
      end
    end
  end
end
