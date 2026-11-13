# frozen_string_literal: true

module DotPopper
  # Whether a bright dot, spawned beneath the others, will offer a touch
  # target (TouchTarget) at some moment within Rules::SPAWN_LOOKAHEAD
  # seconds. It plays the next second forward with the real Dot#move,
  # bounces and all, a STEP at a time, and asks at each step.
  #
  # STEP is 1/30 of a second, the rate the simulator updates at. An
  # opening a STEP or longer always contains a step, so only openings
  # shorter than two frames at 60 Hz go unseen, and nobody can tap one of
  # those on purpose.
  class SpawnCheck < Data.define(:field, :target)
    STEP = 1.0 / 30
    STEPS = (Rules::SPAWN_LOOKAHEAD / STEP).round

    def self.for(field) = new(field:, target: TouchTarget.on(field.radius))

    # Whether +dot+, under every dot in +above+, offers a target now or at
    # some step within the lookahead. A dot too small to hold a target
    # always passes, since no draw could do better.
    #
    # Each dot is moved straight to each step's time from where it began,
    # which Dot#move gives exactly, however many edges it bounces off. A
    # dot far away is not moved at all until it could have come near:
    # on each axis, two dots close no faster than their two speeds on it
    # added, bounces or not, and a dot covers none of the bright one until
    # it is near on both. +soonest+ holds that time for each dot above.
    #
    # On a full screen a step usually fails because one dot above covers
    # every place a target could go, so a step stops at the first such
    # dot without moving the rest, and asks last step's first.
    def exposed_soon?(dot, above)
      return true unless target.fits?

      soonest = Array.new(above.size, 0.0)
      order = (0...above.size).to_a
      (0..STEPS).any? do |step|
        seconds = step * STEP
        bright = at(dot, seconds)
        near = [] #: Array[Dot]
        cover = order.index do |index|
          next false if soonest.fetch(index) > seconds

          moved = at(above.fetch(index), seconds)
          wait = time_to_reach(bright, moved)
          if wait.positive?
            soonest[index] = seconds + wait
            false
          elsif target.covered_by?(bright.x, bright.y, moved)
            true
          else
            near << moved
            false
          end
        end
        order.unshift(order.delete_at(cover)) if cover
        cover.nil? && target.clear_on?(bright.x, bright.y, near)
      end
    end

    private

    def at(dot, seconds) = seconds.zero? ? dot : dot.move(seconds, field)

    # The least time before +other+'s disc could overlap +dot+'s.
    def time_to_reach(dot, other)
      reach = dot.radius + other.radius
      across = time_to_close(dot.x - other.x, dot.velocity_x, other.velocity_x, reach)
      down = time_to_close(dot.y - other.y, dot.velocity_y, other.velocity_y, reach)
      across > down ? across : down
    end

    def time_to_close(apart, speed, other_speed, reach)
      gap = apart.abs - reach
      return 0.0 unless gap.positive?

      closing = speed.abs + other_speed.abs
      closing.zero? ? Float::INFINITY : gap / closing
    end
  end
end
