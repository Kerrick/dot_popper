# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, the edge glow, the dots (tumbling
    # into the Pile after time's up) over the Bloom's glow, the effects
    # over them, the screen's words and HUD on top, and over everything,
    # the gamepad's cursor when it shows. Only the HUD shakes.
    class Renderer
      G = ::Lota::Graphics

      def initialize(show, pen, pile:, sparks:, bloom:)
        @show = show
        @pen = pen
        @pile = pile
        @bloom = bloom
        @dots = DotPainter.new(pen:)
        @effects = EffectsPainter.new(pen:, sparks:)
        @hud = HudPainter.new(pen:)
        @hint = HintPainter.new(pen:)
        @title = TitlePainter.new(pen:, dots: @dots)
        @finale = FinalePainter.new(pen:)
        @cursor = CursorPainter.new(pen:)
        @at_rest = Presentation::DotAnimations.new(pen.look::MOTION)
      end

      def draw(cursor)
        width, height = G.dimensions
        layout = @show.layout
        backdrop(width, height)
        if @show.title?
          @dots.draw(@show.attract.dots, @at_rest, @show.now, radius)
          veil(width, height, @pen.look::TITLE.dim)
          @title.draw(@show, layout)
        else
          @effects.flash(@show.effects, width, height)
          glow
          field
          veil(width, height, @show.finale&.dim(@show.now).to_f) unless @show.playing?
          @effects.scene(@show.effects, dots)
          @effects.words(@show.effects, layout)
          @finale.draw(@show, layout) unless @show.playing?
          hud(layout)
        end
        @cursor.draw(cursor)
      end

      private

      def radius = @show.game.field.radius

      def field
        round = @show.game.round or return
        @dots.draw(dots, @show.animations, @show.now, round.field.radius)
      end

      # The fresh dots' and droplets' light, on the night under every dot,
      # so it never washes out a dot or hints at a fresh dot that is
      # covered.
      def glow
        round = @show.game.round or return
        @bloom.glow do
          @dots.glow(dots, @show.animations, @show.now, round.field.radius)
          @effects.droplets
        end
      end

      # The round's dots where they are drawn: where the rules put them, or
      # after time's up, wherever they have tumbled to in the Pile.
      def dots = @pile.stack || @show.game.round&.dots

      # The score and clock, on top of everything, through Game Over too,
      # so a round ended by a penalty is seen to reach 0. After a wrong tap
      # the HUD shakes, by whole device pixels; the dots never do, since a
      # tap is judged where a dot really is.
      def hud(layout)
        pixels = @pen.pixels
        pill = G.push do
          G.translate(pixels.snap(@show.effects.shake_x), pixels.snap(@show.effects.shake_y))
          @hud.draw(@show.hud, layout)
        end
        @hint.draw(@show.hint, @show.now, layout, pill.bottom) if @show.hint
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
