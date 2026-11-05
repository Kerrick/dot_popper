# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, the edge glow, the dots, the effects
    # over them, and the screen's words and HUD on top. Only the HUD
    # shakes.
    class Renderer
      G = ::Lota::Graphics

      def initialize(show, pen)
        @show = show
        @pen = pen
        @dots = DotPainter.new(pen:)
        @effects = EffectsPainter.new(pen:)
        @hud = HudPainter.new(pen:)
        @title = TitlePainter.new(pen:, dots: @dots)
        @finale = FinalePainter.new(pen:)
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
          @effects.flash(@show.effects, width, height)
          field
          unless @show.playing?
            veil(width, height, @show.finale&.dim(@show.now).to_f)
            @effects.draw(@show.effects, layout, @show.game.round&.dots)
            @finale.draw(@show, layout)
          end
          hud(layout)
        end
      end

      private

      def radius = @show.game.field.radius

      def field
        round = @show.game.round or return
        @dots.draw(round.dots, @show.animations, @show.now, round.field.radius)
        @effects.draw(@show.effects, @show.layout, round.dots) if @show.playing?
      end

      # The score and clock, on top of everything, through Game Over too,
      # so a round ended by a penalty is seen to reach 0. After a wrong tap
      # the HUD shakes, by whole device pixels; the dots never do, since a
      # tap is judged where a dot really is.
      def hud(layout)
        pixels = @pen.pixels
        G.push do
          G.translate(pixels.snap(@show.effects.shake_x), pixels.snap(@show.effects.shake_y))
          @hud.draw(@show.hud, layout)
        end
      end

      public

      # Makes the fonts a frame may need, so the first pop or tick of a
      # round does not stall on making one.
      def prepare = @hud.prepare(@show.layout)

      def backdrop(width, height)
        return flat_backdrop(width, height) unless @pen.shader?(:backdrop)

        @pen.shading(:backdrop) do |shader|
          @pen.uniform(shader, "size", [width.to_f, height.to_f])
          G.color = [1, 1, 1, 1]
          @pen.square(width / 2.0, height / 2.0, width / 2.0, height / 2.0)
        end
      end

      # Without its shader, the night is bands from top to bottom.
      def flat_backdrop(width, height)
        palette = @pen.palette
        bands = 16
        bands.times do |i|
          @pen.color(palette.ink_top.mix(palette.ink_bottom, i / (bands - 1.0)))
          G.rectangle(:fill, 0, height * i / bands, width, (height / bands.to_f) + 1)
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
