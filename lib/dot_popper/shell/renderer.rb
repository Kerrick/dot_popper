# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, the edge glow, the dots (tumbling
    # into the Pile after time's up) over the Bloom's glow, the rings and
    # outlines that follow them, which after time's up are the pile's and
    # dim with it, under Game Over's card and buttons, the numbers that
    # float up, the screen's words and HUD on top, the share preview over
    # those when it is open, and over everything, the gamepad's cursor
    # when it shows. Only the HUD shakes. The Tutorial is drawn as a round
    # is, from its own dots and HUD, with its spotlight, hand and skip
    # button over them.
    class Renderer
      G = ::Lota::Graphics

      # With +diagnostic+ (DOT_POPPER_DIAGNOSTIC_COLORS), each frame clears
      # to pure blue and draws no night, so any pixel the game's drawing
      # reaches but nothing paints shows blue (doc/ios.md).
      def initialize(show, pen, pile:, sparks:, bloom:, diagnostic: false)
        @show = show
        @diagnostic = diagnostic
        @pen = pen
        @pile = pile
        @bloom = bloom
        @dots = DotPainter.new(pen:)
        @effects = EffectsPainter.new(pen:, sparks:)
        @hud = HudPainter.new(pen:)
        @title = TitlePainter.new(pen:, dots: @dots)
        @records = RecordsPainter.new(pen:)
        @credits = CreditsPainter.new(pen:)
        @looks = LooksPainter.new(pen:, dots: @dots)
        @finale = FinalePainter.new(pen:)
        @share = SharePreviewPainter.new(pen:, dots: @dots)
        @cursor = CursorPainter.new(pen:)
        @splash = SplashPainter.new(pen:)
        @tutorial = TutorialPainter.new(pen:)
        @at_rest = Presentation::DotAnimations.new(pen.look::MOTION)
      end

      # The frame, with the setdef +splash+ over it while there is one.
      def draw(cursor, splash = nil)
        width, height = cover
        layout = @show.layout
        backdrop(width, height)
        if @show.tutorial?
          tutorial(width, height, layout)
        elsif @show.title?
          @dots.draw(@show.attract.dots, @at_rest, @show.now, radius)
          if @show.records?
            veil(width, height, @pen.look::RECORDS.veil)
            records_screen.draw(@show, layout)
          else
            veil(width, height, @pen.look::TITLE.dim)
            @title.draw(@show, layout)
          end
        else
          @effects.flash(@show.effects, width, height)
          glow
          field
          @effects.scene(@show.effects, dots)
          veil(width, height, @show.finale&.dim(@show.now).to_f) unless @show.playing?
          @effects.words(@show.effects, layout)
          @finale.draw(@show, layout) unless @show.playing?
          lead_in = @show.lead_in
          if lead_in
            pill = @hud.bounds(@show.hud, layout)
            @tutorial.lead_in_under(lead_in, @show.now, pill, @hud.spots(@show.hud, layout),
                                     @show.game.round.field.radius)
          end
          hud(layout)
          @tutorial.lead_in_over(lead_in, @show.now, pill) if lead_in
          @share.draw(@show, layout, width, height)
        end
        splash ? @splash.draw(splash) : @cursor.draw(cursor)
      end

      private

      def radius = @show.game.field.radius

      # The screen open over the title's dimmed dots: Credits, Looks, or
      # the Records screen they were opened from.
      def records_screen
        if @show.credits? then @credits
        elsif @show.looks? then @looks
        else @records
        end
      end

      # The Tutorial, drawn as the round it opens is: its dots over their
      # glow and the effects of its taps, its HUD, never shaken, and its
      # spotlight, guide and skip button over them all.
      def tutorial(width, height, layout)
        scene = @show.tutorial
        @effects.flash(@show.effects, width, height)
        @bloom.glow do
          @dots.glow(scene.dots, scene.animations, scene.now, scene.radius)
          @effects.droplets
        end
        @dots.draw(scene.dots, scene.animations, scene.now, scene.radius)
        @effects.scene(@show.effects, scene.dots)
        @effects.words(@show.effects, layout)
        pill = @hud.bounds(scene.hud, layout)
        spots = @hud.spots(scene.hud, layout)
        @tutorial.under_hud(scene, pill, spots)
        @hud.draw(scene.hud, layout)
        @tutorial.over_hud(@show, scene, layout, pill, spots)
      end

      # How far the night and the veils must reach to cover every pixel:
      # a unit past Lota's dimensions. Those are whole units, rounded
      # down, while the drawable may be a fraction of a unit wider: on an
      # iPhone 13 mini turned landscape it is 2338 pixels at a scale of
      # 2.88, 811.8 units, which Lota calls 811, and a night that stopped
      # there left the last two columns of pixels undrawn.
      def cover
        width, height = G.dimensions
        [width + 1, height + 1]
      end

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
        G.push do
          G.translate(pixels.snap(@show.effects.shake_x), pixels.snap(@show.effects.shake_y))
          @hud.draw(@show.hud, layout)
        end
      end

      public

      # Makes the fonts a frame may need, so the first pop or tick of a
      # round does not stall on making one, and clears each frame to the
      # night's darkest ink, so a pixel nothing draws is never black or
      # another color.
      def prepare
        G.background_color = @pen.palette.ink_edge.to_a
        @splash.refresh
        @hud.prepare(@show.layout)
      end

      def backdrop(width, height)
        return G.clear(0, 0, 1, 1) if @diagnostic
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
