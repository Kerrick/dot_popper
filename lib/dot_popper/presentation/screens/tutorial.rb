# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # The Tutorial over the first game, paused (ADR-0016): its scene
      # (Presentation::Tutorial), while it plays, and Skip, its only button.
      class Tutorial < Screen
        # The scene playing, or nil.
        attr_reader :scene

        # Whether it is playing over its paused game.
        def playing? = !@scene.nil?

        # It plays +scene+ over the game started paused for it.
        def play(scene) = @scene = scene

        # The scene moves on +seconds+; once it is over, it goes (#finish),
        # and says so.
        def follow(seconds)
          @scene.update(seconds)
          return false unless @scene.over?

          finish
          true
        end

        # Skip: the scene shows at once what it had yet to show of the game,
        # and goes. Nothing starts or ends: the game began when it opened.
        def skip
          return unless playing?

          @scene.catch_up
          finish
        end

        # The scene it handed the game as it went, once: the game is drawn
        # on as the Tutorial drew it (Show#game_started).
        def take_handed_over
          scene, @handed_over = @handed_over, nil
          scene
        end

        def controls = [button(:skip, layout.skip_button)]

        # Escape or B skips it.
        def back
          skip
          true
        end

        def answers = [:skip]

        def pressed(name, _by) = (skip if name == :skip)

        # A tap on Skip presses it; any other is the Tutorial's own, which
        # it passes on to its scene (Presentation::Tutorial#tap).
        def tap(x, y, by)
          return super if show.control_at(x, y)

          @scene.tap(x, y)
        end

        private

        # It goes, and its game plays on as it is (Cabinet#unpause).
        def finish
          @handed_over, @scene = @scene, nil
          show.cabinet.unpause
        end
      end
    end
  end
end
