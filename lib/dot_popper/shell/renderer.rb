# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, then the dots (shaken a little after a
    # wrong tap), the effects over them, the edge glow, and the screen's
    # words and HUD on top, which never shake.
    class Renderer
      G = ::Lota::Graphics

      def initialize(show, pen)
        @show = show
        @pen = pen
        @dots = DotPainter.new(pen)
        @effects = EffectsPainter.new(pen)
        @hud = HudPainter.new(pen)
        @title = TitlePainter.new(pen, @dots)
        @finale = FinalePainter.new(pen)
        @at_rest = Presentation::DotAnimations.new(pen.look::MOTION)
      end

      def draw
        width, height = G.dimensions
        layout = @show.layout
        backdrop(width, height)
        if @show.title?
          @dots.draw(@show.attract.dots, @at_rest, @show.now, radius)
          veil(width, height, @pen.look::TITLE.dim)
          @title.draw(@show, layout)
        else
          field
          @effects.flash(@show.effects.flash, width, height)
          if @show.playing?
            @hud.draw(@show.hud, layout)
          else
            veil(width, height, @show.finale&.dim(@show.now).to_f)
            @effects.draw(@show.effects, layout)
            @finale.draw(@show, layout)
          end
        end
      end

      private

      def radius = @show.game.field.radius

      def field
        round = @show.game.round or return
        shake = @show.effects.shake
        G.push do
          G.translate(shake.offset_x, shake.offset_y)
          @dots.draw(round.dots, @show.animations, @show.now, round.field.radius)
          @effects.draw(@show.effects, @show.layout) if @show.playing?
        end
      end

      def backdrop(width, height)
        @pen.shading(:backdrop) do |shader|
          @pen.send(shader, "size", [width.to_f, height.to_f])
          G.color = [1, 1, 1, 1]
          @pen.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      # The ink drawn over dots that are only scenery.
      def veil(width, height, alpha)
        return if alpha <= 0.0

        @pen.color(@pen.palette.ink_bottom, alpha)
        G.rectangle(:fill, 0, 0, width, height)
      end
    end
  end
end
