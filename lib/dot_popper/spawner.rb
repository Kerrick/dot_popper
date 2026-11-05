# frozen_string_literal: true

module DotPopper
  # Draws each fresh dot: a uniformly random place and velocity, as the
  # spec has it, unless SpawnCheck finds the draw would leave the dot
  # without a touch target for the next second. Then it draws the
  # velocity again, keeping the place, up to +tries+ times, and then the
  # place and velocity together, up to +tries+ more. If every try fails,
  # on a field packed solid, the last draw stands, so a dot always spawns.
  #
  # A draw that passes the first time costs no more randomness than
  # before, so seeded rounds replay as they did unless a redraw happens.
  # With +tries+ at 0, every draw stands, which is the rule before it.
  class Spawner < Data.define(:check, :tries)
    def self.for(field, tries: Rules::SPAWN_TRIES) = new(check: SpawnCheck.for(field), tries:)

    def field = check.field

    # A Spawn for a dot of +id+ going in beneath every dot in +above+.
    def spawn(random, id:, above:)
      dot = Dot.spawn(field, random, id:)
      return Spawn.new(dot:) if check.exposed_soon?(dot, above)

      tries.times do |try|
        dot = dot.with(velocity_x: field.random_speed(random), velocity_y: field.random_speed(random))
        return Spawn.new(dot:, velocity_redraws: try + 1) if check.exposed_soon?(dot, above)
      end
      tries.times do |try|
        dot = Dot.spawn(field, random, id:)
        return Spawn.new(dot:, velocity_redraws: tries, position_redraws: try + 1) if check.exposed_soon?(dot, above)
      end
      Spawn.new(dot:, velocity_redraws: tries, position_redraws: tries, exposed: false)
    end
  end
end
