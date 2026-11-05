# frozen_string_literal: true

module DotPopper
  module Shell
    # The game-over pile. When a round ends its rules are frozen and its
    # dots are only scenery, so they are handed to a Box2D world: each dot
    # becomes a ball where it was, going as it went, and falls under
    # gravity between the window's sides onto its floor. A new round or
    # the title throws the world away.
    #
    # It hears the rules' events (Game#subscribe). While a pile is falling,
    # +stack+ is the round's stack with each dot where its ball is, in the
    # same order, so popped dots still cover fresh ones.
    class Pile
      P = ::Lota::Physics

      def initialize(look)
        @look = look
        @world = nil
      end

      def call(event)
        case event
        when Events::RoundEnded then fill(event.round)
        when Events::RoundStarted, Events::TitleShown then empty
        end
      end

      def falling? = !@world.nil?

      def update(seconds)
        @world&.update(@look.step(seconds))
      end

      # The round's stack, every dot moved to its ball; nil with no pile.
      def stack
        return unless @world

        @stack.map_dots do |dot|
          x, y = @balls.fetch(dot.id).position
          dot.with(x:, y:)
        end
      end

      # The window changed size, or a tablet turned: the walls move to its
      # new edges, and a ball the new walls would leave outside comes back
      # in, since Box2D never pushes a body back through a wall.
      def refit(field)
        return unless @world

        @walls.destroy
        @walls = walls(field)
        @balls.each_value { bring_inside(it, field) }
      end

      private

      def fill(round)
        empty
        radius = round.field.radius
        P.meter = @look.meter_for(radius)
        @world = P::World.new(0, @look.gravity_for(radius), true)
        @walls = walls(round.field)
        @stack = round.dots
        @balls = @stack.to_h { [it.id, ball(it)] }
      rescue StandardError => e
        warn "Dot Popper: the dots stay put at game over (#{e.message})"
        @world = nil
      end

      def empty
        @world&.destroy
        @world = @walls = @stack = @balls = nil
      end

      def ball(dot)
        body = P::Body.new(@world, dot.x, dot.y, :dynamic)
        shape = P::CircleShape.new(body, dot.radius)
        shape.restitution = @look.restitution
        shape.friction = @look.friction
        shape.density = @look.density
        body.reset_mass_data
        body.linear_damping = @look.damping
        body.linear_velocity = @look.launch(dot)
        body
      end

      def bring_inside(body, field)
        x, y = body.position
        inside = [x.clamp(field.min_x, field.max_x), [y, field.max_y].min]
        return if inside == [x, y]

        body.position = inside
        body.linear_velocity = [0, 1] # wakes it, as Box2D wakes a body given any speed
      end

      def walls(field)
        body = P::Body.new(@world, 0, 0, :static)
        Presentation::PileWalls.new(width: field.width, height: field.height).segments.each do |segment|
          P::EdgeShape.new(body, *segment).friction = @look.friction
        end
        body
      end
    end
  end
end
