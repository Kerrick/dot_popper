# frozen_string_literal: true

module DotPopper
  module Shell
    # The game-over pile. When a game ends its rules are frozen and its
    # dots are only scenery, so they are handed to a Box2D world: each dot
    # becomes a ball where it was, going as it went, and falls under
    # gravity between the window's sides onto its floor. A new game or
    # Home throws the world away.
    #
    # It hears the rules' events (Cabinet#subscribe). While a pile is falling,
    # +stack+ is the game's stack with each dot where its ball is, in the
    # same order, so popped dots still cover bright ones.
    #
    # Tilting (Shell::Tilting) may turn its gravity, wake its sleeping
    # balls, and throw them, and Dragging (Shell::Dragging) may steer a
    # ball under a pointer; once either does, a lid closes the window's
    # top.
    class Pile
      # How many radii make one of Box2D's meters: Box2D is tuned for
      # objects of about a meter, so a dot is a ball one meter across.
      METER = 2.0

      # One of Box2D's meters, in graphics units, for a dot of +radius+.
      def self.meter_for(radius) = METER * radius

      def initialize(style)
        @style = style
        @world = nil
      end

      def call(event)
        case event
        when Events::GameEnded then fill(event)
        when Events::GameStarted, Events::HomeShown then empty
        end
      end

      def falling? = !@world.nil?

      def update(seconds)
        @world&.update(@style.step(seconds))
      end

      # Pulls the balls toward +pull+ (a Presentation::Gravity, 1 being the
      # pile's own gravity) from now on, under a lid. With +wake+, every
      # ball asleep wakes, since Box2D leaves a sleeping body where it is
      # whatever the gravity does.
      def tilt(pull, wake: false)
        return unless @world

        close_lid
        @world.gravity = pull.gravity(@style.gravity_for(@radius))
        @balls.each_value { wake(it) } if wake
      end

      # Adds to each ball's velocity what the block gives for the dots'
      # radius, as [x, y] in graphics units a second: a shake.
      def throw_balls
        return unless @world

        @balls.each_value do |body|
          vx, vy = body.linear_velocity
          kx, ky = yield(@radius)
          body.linear_velocity = [vx + kx, vy + ky]
        end
      end

      # The radius of the pile's dots, or nil with no pile.
      def radius = (@radius if @world)

      # The topmost ball at +x+, +y+, as its dot's id and its middle, or
      # nil.
      def ball_at(x, y)
        dot = stack&.top_at(x, y) or return
        [dot.id, [dot.x, dot.y]]
      end

      # The middle of the ball for dot +id+, or nil.
      def center(id) = @balls&.[](id)&.position

      # Sets the ball for dot +id+ going at +velocity+, [x, y] in graphics
      # units a second, under a lid. A held ball is a bullet, so Box2D
      # checks every step that it has not passed through a wall or a dot.
      def steer(id, velocity)
        body = @balls&.[](id) or return
        close_lid
        body.bullet = true
        body.linear_velocity = velocity
      end

      # Lets the ball for dot +id+ go at +velocity+, or at the speed it has
      # with nil.
      def let_go(id, velocity)
        body = @balls&.[](id) or return
        body.bullet = false
        body.linear_velocity = velocity if velocity
      end

      # The game's stack, every dot moved to its ball; nil with no pile.
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

        @field = field
        @walls.destroy
        @walls = walls(field)
        @balls.each_value { bring_inside(it, field) }
      end

      private

      def physics = ::Lota::Physics

      # The finished game's dots (Events::GameEnded), where they were as
      # its clock reached zero, begin to fall.
      def fill(ended)
        empty
        radius = @radius = ended.field.radius
        @field = ended.field
        @lid = false
        physics.meter = self.class.meter_for(radius)
        @world = physics::World.new(0, @style.gravity_for(radius), true)
        @walls = walls(ended.field)
        @stack = ended.dots
        @balls = @stack.to_h { [it.id, ball(it)] }
      rescue StandardError => e
        warn "Dot Popper: the dots stay put at game over (#{e.message})"
        @world = nil
      end

      def empty
        @world&.destroy
        @world = @walls = @stack = @balls = @field = nil
      end

      def ball(dot)
        body = physics::Body.new(@world, dot.x, dot.y, :dynamic)
        shape = physics::CircleShape.new(body, dot.radius)
        shape.restitution = @style.restitution
        shape.friction = @style.friction
        shape.density = @style.density
        body.reset_mass_data
        body.linear_damping = @style.damping
        body.linear_velocity = @style.launch(dot)
        body
      end

      # The lid goes on once, and any ball still above the window, thrown
      # up as the game ended, comes down inside it first.
      def close_lid
        return if @lid

        @lid = true
        refit(@field)
      end

      def bring_inside(body, field)
        x, y = body.position
        top = @lid ? field.min_y : -Float::INFINITY
        inside = [x.clamp(field.min_x, field.max_x), y.clamp(top, field.max_y)]
        return if inside == [x, y]

        body.position = inside
        body.linear_velocity = [0, 1] # wakes it, as Box2D wakes a body given any speed
      end

      # Box2D wakes a body given any speed (Lota binds no setAwake), so a
      # ball at rest is given the least nudge, along the pull.
      def wake(body)
        vx, vy = body.linear_velocity
        gx, gy = @world.gravity
        body.linear_velocity = vx.zero? && vy.zero? ? [gx * 1e-3, gy * 1e-3] : [vx, vy]
      end

      def walls(field)
        body = physics::Body.new(@world, 0, 0, :static)
        Presentation::PileWalls.new(width: field.width, height: field.height, lid: @lid).segments.each do |segment|
          physics::EdgeShape.new(body, *segment).friction = @style.friction
        end
        body
      end
    end
  end
end
