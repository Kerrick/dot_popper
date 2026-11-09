# frozen_string_literal: true

module DotPopper
  module Shell
    # Lets the player drag the game-over pile's dots about with a mouse or
    # fingers, and throw them. Presentation::PileGrabs decides what each
    # press is; this tells it where the pointers are and carries out what
    # it says on the Pile: each held ball is steered toward its pointer
    # every frame, a ball let go flies off, and a click goes to the Show,
    # which presses a button there, or, for a gamepad's A, Continue.
    #
    # Lota 0.1.3 binds MouseJoint.new but none of its setters, so a joint
    # could never follow the pointer; a held ball is instead given the
    # velocity that closes on it, which Box2D's contacts and walls still
    # stop, as a joint's pull would be.
    #
    # It hears the rules' events (Cabinet#subscribe), after the Pile does,
    # and drops every pointer when the pile goes.
    class Dragging
      def initialize(pile:, show:, look:)
        @pile = pile
        @show = show
        @look = look
        @grabs = Presentation::PileGrabs.new(look)
      end

      def call(event)
        case event
        when Events::GameEnded, Events::GameStarted, Events::TitleShown then drop
        end
      end

      # A pointer went down where the Show waits for its release.
      def press(key, x, y)
        id, center = @pile.ball_at(x, y)
        let_go(@grabs.press(key, x, y, now:, radius: @pile.radius || 1.0, heard: @show.cabinet.state.ready?,
                                       ball: id, center:))
      end

      def move(key, x, y) = @grabs.move(key, x, y, now:)

      def release(key, x, y)
        case @grabs.release(key, x, y, now:)
        in Presentation::Fling => fling then let_go(fling)
        in Presentation::Click => click then @show.tap(click.x, click.y, by: key)
        in nil then nil
        end
      end

      # Lets every ball go, as when the window loses focus, since a finger
      # lifted meanwhile is never heard.
      def drop = @grabs.drop_all.each { let_go(it) }

      def update(_seconds)
        @grabs.update(now)
        @grabs.drags.each do |grab|
          center = @pile.center(grab.ball) or next
          @pile.steer(grab.ball, grab.pull(center, @look))
        end
      end

      private

      def let_go(fling) = fling && @pile.let_go(fling.ball, fling.velocity)

      def now = @show.now
    end
  end
end
