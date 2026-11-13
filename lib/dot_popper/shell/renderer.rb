# frozen_string_literal: true

module DotPopper
  module Shell
    # Draws a frame of the Show, straight to the window at its own
    # resolution: the night behind, the edge glow, the dots (tumbling
    # into the Pile after time's up) over the Bloom's glow, the rings and
    # outlines that follow them, which after time's up are the pile's and
    # dim with it, under Game Over's card and buttons, the numbers that
    # float up, the screen's words and HUD on top, the screens open over
    # the game's state (Show#layers), each by its painter, and over
    # everything, the gamepad's cursor when it shows. Only the HUD shakes.
    # The Tutorial is drawn as a game is, from its own dots and HUD, with
    # its spotlight, hand and skip button over them.
    class Renderer
      G = ::Lota::Graphics
      Screens = Presentation::Screens

      # With +diagnostic+ (DOT_POPPER_DIAGNOSTIC_COLORS), each frame clears
      # to pure blue and draws no night, so any pixel the game's drawing
      # reaches but nothing paints shows blue (doc/ios.md).
      def initialize(show, pen, pile:, sparks:, bloom:, diagnostic: false)
        @show = show
        @diagnostic = diagnostic
        @pen = pen
        @pile = pile
        @bloom = bloom
        @dots = DotPainter.new(pen:, clock: -> { @show.now })
        @effects = EffectsPainter.new(pen:, sparks:)
        @hud = HudPainter.new(pen:, dots: @dots)
        @home = HomePainter.new(pen:, dots: @dots)
        @stats = StatsPainter.new(pen:)
        @settings = SettingsPainter.new(pen:, dots: @dots)
        @achievements = AchievementsPainter.new(pen:)
        @privacy = PrivacyPainter.new(pen:)
        @server = ServerPainter.new(pen:)
        @credits = CreditsPainter.new(pen:)
        @themes = ThemesPainter.new(pen:, dots: @dots)
        @offer = OfferPainter.new(pen:, dots: @dots)
        @game_over = GameOverPainter.new(pen:, dots: @dots)
        @group = GroupPainter.new(pen:)
        @share = SharePreviewPainter.new(pen:, dots: @dots)
        @cursor = CursorPainter.new(pen:)
        @splash = SplashPainter.new(pen:)
        @scene = Scene.new(pen)
        @arrival = ArrivalPainter.new(pen:, dots: @dots)
        @tutorial = TutorialPainter.new(pen:)
        @at_rest = Presentation::DotAnimations.new(pen.style::MOTION)
        @pages = { Screens::Stats => @stats, Screens::Themes => @themes, Screens::Credits => @credits,
                   Screens::Achievements => @achievements }.freeze
      end

      # The frame, with the setdef +splash+ over it while there is one:
      # what the Show says is showing (Show#screen). Under everything is
      # the game's state: Home's dots, the Tutorial over its game, or a
      # game and after it Game Over. Over that, the screens open over it,
      # from the last that covers the rest up to the top one.
      def draw(cursor, splash = nil)
        width, height = cover
        layout = @show.layout
        backdrop(width, height)
        state = @show.state_screen
        case state
        when Screens::Tutorial then tutorial(width, height, layout)
        when Screens::Home, Screens::NewTheme then @dots.draw(@show.attract.dots, @at_rest, @show.now, radius)
        else game(width, height, layout)
        end
        screens(state, width, height, layout)
        banner(layout) if @show.screen.announces?
        splash ? @splash.draw(splash) : @cursor.draw(cursor)
      end

      private

      # The screens over the game's state, from the last one that covers
      # the rest (or the screen for the state itself) up to the top one.
      def screens(state, width, height, layout)
        layers = @show.layers
        from = layers.rindex { it.covers? }
        draw_screen(state, width, height, layout) unless from
        (from || 0).upto(layers.size - 1) { draw_screen(layers[it], width, height, layout) }
      end

      # One screen, over the veil it draws over what is under it.
      def draw_screen(screen, width, height, layout)
        case screen
        when Screens::Home, Screens::NewTheme
          veil(width, height, @pen.style::HOME.dim)
          @home.draw(@show, layout)
          @arrival.draw(@show, layout) if screen.is_a?(Screens::NewTheme)
        when Screens::Settings
          veil(width, height, @pen.style::STATS.veil)
          @settings.draw(screen.drawing)
        when Screens::ChangeServer
          veil(width, height, @pen.style::STATS.veil)
          @server.draw(screen.drawing)
        when Screens::Privacy
          veil(width, height, @pen.style::STATS.veil)
          @privacy.draw(screen.drawing)
        when Screens::Page
          veil(width, height, @pen.style::STATS.veil)
          @pages.fetch(screen.class).draw(@show, layout)
        when Screens::AchievementDialog then @achievements.dialog(@show, layout)
        when Screens::FriendGroups
          veil(width, height, @pen.style::GROUPS.veil)
          @group.draw(@show, layout)
        when Screens::Offer
          veil(width, height, @pen.style::STATS.veil)
          @offer.draw(@show, layout)
        when Screens::SharePreview then @share.draw(@show, layout, width, height)
        end
      end

      # A game, and after it, Game Over over its pile: the dots over their
      # glow, the effects, the veil and words of Game Over, the lead-in
      # after the Tutorial, and the HUD until Game Over has arrived.
      def game(width, height, layout)
        @effects.flash(@show.effects, width, height)
        glow
        field
        @effects.scene(@show.effects, dots)
        veil(width, height, @show.game_over&.dim(@show.now).to_f) unless @show.playing?
        @effects.words(@show.effects, layout)
        @game_over.draw(@show, layout) unless @show.playing?
        lead_in = @show.clock_highlight
        if lead_in
          pill = @hud.bounds(@show.hud, layout)
          @tutorial.lead_in_under(lead_in, @show.now, pill, @hud.spots(@show.hud, layout),
                                   @show.cabinet.game.field.radius)
        end
        hud(layout) unless @show.game_over&.then { it.arrival(@show.now) >= 1.0 }
        @tutorial.lead_in_over(lead_in, @show.now, pill) if lead_in
      end

      # A title change's announcement, for the few seconds it shows.
      def banner(layout) = @group.banner(@show.group_panel.banner, @show.now, layout, @show.banner_y)

      def radius = @show.cabinet.field.radius

      # The Tutorial, drawn as the game it opens is: its dots over their
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
        game = @show.cabinet.game or return
        @dots.draw(dots, @show.animations, @show.now, game.field.radius)
      end

      # The bright dots' and droplets' light, on the night under every dot,
      # so it never washes out a dot or hints at a bright dot that is
      # covered.
      def glow
        game = @show.cabinet.game or return
        @bloom.glow do
          @dots.glow(dots, @show.animations, @show.now, game.field.radius)
          @effects.droplets
        end
      end

      # The game's dots where they are drawn: where the rules put them, or
      # after time's up, wherever they have tumbled to in the Pile.
      def dots = @pile.stack || @show.cabinet.game&.dots

      # The score and clock, on top of everything, until Game Over has
      # arrived, so a game ended by a penalty is seen to reach 0; Game
      # Over then shows the score itself. After a mistake
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
      # game does not stall on making one, and clears each frame to the
      # night's darkest ink, so a pixel nothing draws is never black or
      # another color.
      def prepare
        G.background_color = @pen.palette.ink_edge.to_a
        @scene.bake(@pen.art)
        @splash.refresh
        @hud.prepare(@show.layout)
      end

      def backdrop(width, height)
        return G.clear(0, 0, 1, 1) if @diagnostic
        return @scene.draw if @scene.on?
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
