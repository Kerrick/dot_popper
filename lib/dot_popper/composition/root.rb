# frozen_string_literal: true

require "uri"
require_relative "../presentation"
require_relative "developer_settings"
require_relative "use_cases"

module DotPopper
  module Composition
    # The composition root: builds the whole game for one platform and one
    # kind of build, and decides what it is built from, with no Lota. What
    # only the engine can make or do, it asks of +engine+ (Shell::Engine in
    # the game, a fake in the tests):
    #
    # [platform] the Platform the game runs on
    # [unit] what a graphics unit is called there, to print
    # [file(name)] the store for a save file (read, write, remove)
    # [dimensions] the window's width and height in graphics units
    # [layout] the window's Presentation::Layout, with its safe area
    # [fill_screen] fills a phone's or tablet's screen
    # [open_window(radius:, wanted:, smallest:)] sizes a computer's window
    # [desktop_window(exclusive:)] a computer's window control
    # [pen(shaders:)], [measure(pen)] what draws, and how wide text is in
    #   its fonts
    # [sound_player(store:)] what plays the sounds
    # [clipboard], [opener], [buzzer] the system's clipboard, its URL
    #   opener, and its vibration motor
    # [notices] the notices Credits shows
    # [store_helper(automated:)] a computer's store helper
    # [store_answers] the file the phone host writes the store's answers to
    # [say(line)] prints a line about the run
    # [path(name)] where the save file +name+ is, to print
    #
    # +settings+ (DeveloperSettings) are the developer settings this build obeys,
    # and +clock+ the wall clock in seconds, which Refresh keeps its floor
    # by. Nothing here starts a thread or asks anything of the network
    # until #start.
    class Root
      Style = Presentation::Style
      GAMES_LOG = "games.csv"
      # The old name, until no commit uses it.
      PLAYTEST_LOG = GAMES_LOG
      SMALLEST_WINDOW = [400, 320].freeze

      attr_reader :settings, :platform, :dot_size, :window, :cabinet, :show, :pen, :sound_player, :splash, :storefront,
                  :entitlement, :theme_feed, :watch, :cursor, :bot, :haptics, :sharing, :refresh

      # Its old name, until no caller says it.
      alias autopilot bot

      def initialize(engine:, settings: DeveloperSettings.new, clock: -> { Time.now.to_f })
        @engine = engine
        @settings = settings
        @clock = clock
        @platform = engine.platform
        @dot_size = DotSize.for(platform, unit: engine.unit)
        engine.say("a dot's radius is #{dot_size.reason}")
        # With DOT_POPPER_PERF=1: whether this build's Ruby verifies
        # Ed25519, which the packaged-app playthroughs check. Where it
        # does not, setdef is never found gone (Continuity::Watch).
        engine.say("Ed25519 #{Continuity::Ed25519.available? ? "verifies" : "does not verify"} the server's test vector") if flag?("DOT_POPPER_PERF")
        open_window
        build
      end

      # Starts what reaches past this process: the theme feed's first
      # request, the store's first question, and the watch for setdef.
      # Only the first and the friend groups' are asked again (Refresh);
      # the rest are once each time the game starts.
      def start
        theme_feed&.ask
        storefront.connect
        watch.start
      end

      # The window as a field of dots at the usual size; the game sizes a
      # game's dots on it as the player chose (DotSizing).
      def screen = dot_size.field(*@engine.dimensions)

      # How the Game Over pile falls, is dragged, and tilts: softly, with
      # DOT_POPPER_CALM.
      def pile_style = settings.calm? ? Style::CALM_PILE : Style::PILE
      def grab_style = settings.calm? ? Style::CALM_GRAB : Style::GRAB
      def tilt_style = settings.calm? ? Style::CALM_TILT : Style::TILT

      # DOT_POPPER_FAKE_TILT's steady reading, in place of an accelerometer,
      # or nil.
      def fake_tilt = Presentation::Reading.parse(settings["DOT_POPPER_FAKE_TILT"])

      # The games a free player has left, counted as +metered+ says
      # (FreeGames.metered?), starting as a developer may ask
      # (FreeGames.starting).
      def free_games(entitlement, metered:, store: file("games.txt"))
        start = FreeGames.starting(settings.env)
        FreeGames.new(store, today: settings.today, entitlement:, metered:,
                             **(start ? { first_games: start, daily: start } : {}))
      end

      # The native port: on a phone the app's host, by URL and answer file;
      # on a computer sold through its own store, the store helper shipped
      # in the app, by its pipe (Shell::StoreHelper). Which one a build uses
      # is Store.for's choice, by the channel.
      def native_store
        return @engine.store_helper(automated: settings.automated?) if platform.own_store

        NativeStore.new(opener: @engine.opener, answers: @engine.store_answers)
      end

      # The server friend groups and themes use: setdef's, or while setdef
      # is gone, a replacement the player chose (Presentation::ServerChoice),
      # or none in an automated run.
      def server_url
        own = Network::Server.server_url(settings.env) or return
        @server_choice.server_url(own)
      end

      private

      def flag?(name) = settings.flag?(name)
      def file(name) = @engine.file(name)

      # A phone's or tablet's game fills its screen; a computer's window is
      # sized to the play area, or to DOT_POPPER_WINDOW's size. A desktop's
      # title offers "Full screen" and Quit; a phone's or tablet's game
      # leaves by the system.
      def open_window
        if platform.touch?
          @engine.fill_screen
          @window = Presentation::NoWindowControl.new
        else
          @engine.open_window(radius: dot_size.radius, wanted: settings.window_size(SMALLEST_WINDOW), smallest: SMALLEST_WINDOW)
          @window = @engine.desktop_window(exclusive: settings["DOT_POPPER_FULLSCREEN"] == "exclusive")
        end
      end

      def build
        today = settings.today
        random = settings.seed ? Random.new(settings.seed) : Random.new
        # A record saved before records were kept by size of screen goes to
        # this screen's class.
        legacy = SizeClass.of(screen)
        sizing_store = file("dot_size.txt")
        @cabinet = Cabinet.new(screen, score_record: ScoreRecord.new(file("score_record.txt"), legacy:), random:,
                                       sizing: DotSizing.parse(sizing_store.read))
        @engine.say("dots are standard, worked out from the screen as each game starts") if @cabinet.sizing.standard?
        stats_book = StatsBook.new(file("stats.txt"), today:, legacy:)
        achievements = Achievements.new(file("achievements.txt"))
        keeper = StatsBackup.new(score_record: @cabinet.score_record, stats_book:, achievements:, folder: ->(name) { file(name) })
        @gone = Continuity::Gone.new(file("setdef.txt"))
        # What this build trusts, and where it keeps a license key, as
        # Monetization decides by the channel alone (ADR-0010).
        channel = settings.channel
        pins = Continuity.pins_for(channel)
        license = Continuity::License.new(Continuity::License.kept_in(channel) { file("license.txt") }, pins:)
        @watch = watch_for(license, pins)
        @entitlement = Entitlement.new(forced: Entitlement.forced?(settings.env, platform:), license:, trust: Receipt.trusted(channel))
        clipboard = @engine.clipboard
        @server_choice = Presentation::ServerChoice.new(file("server.txt"), gone: @gone, clipboard:)
        theme_keeper = Presentation::ThemeKeeper.new(file("themes.txt"), themes: Style::THEMES)
        use_theme = UseCases::UseTheme.new(themes: theme_keeper.rules, entitlement:)
        use_fixture(theme_keeper, use_theme)
        theme_keeper.open_by_date(today.call, @gone.days(today.call))
        @gone.subscribe(@server_choice).subscribe(theme_keeper)
        @theme_feed = theme_feed_for(theme_keeper)
        @pen = @engine.pen(shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        current = Style::THEMES.find { it.key == use_theme.current }
        @pen.use(current)
        @sound_player = @engine.sound_player(store: file("sound.txt"))
        @sound_player.use(current)
        unless Presentation::Splash.skipped?(settings.env)
          @splash = Presentation::Splash.start(calm: settings.calm?, sounding: !@sound_player.muted?)
        end
        @storefront = Store.for(
          platform, entitlement:, channel: settings.channel, native: native_store,
                    fake: FakeStore.new(file("fake_store.txt"), fails: FakeStore.failure(settings.env)),
                    website: ->(fake:) { website_store(clipboard, fake:) }
        )
        games = free_games(entitlement, metered: FreeGames.metered?(settings.env, channel:, offered: storefront.offered?))
        @haptics = platform.buzzes? ? @engine.buzzer : Presentation::NoHaptics.new
        @sharing = Presentation::SheetSharing.for(platform, opener: @engine.opener)
        groups = groups_session
        use_cases = Composition.use_cases(cabinet: @cabinet, free_games: games, entitlement:, store: storefront, achievements:,
                                          stats_book:, friend_groups: groups, use_theme:)
        @show = Presentation::Show.new(
          groups:, cabinet: @cabinet, layout: @engine.layout, sounds: @sound_player, radius: dot_size.radius,
          random:, calm: settings.calm?, tutor: Presentation::Tutor.new(file("taught.txt"), times: Style::LESSON.times),
          haptics:, clipboard:, notices: @engine.notices, sharing:,
          stats_book:, achievements:, keeper:, sizing_store:, input: starting_input, measure: @engine.measure(@pen),
          window: @window,
          tutorial_flag: Presentation::TutorialFlag.new(file("tutorial.txt"), mode: Presentation::TutorialFlag.mode(settings.env)),
          group_notice: Presentation::GroupNotice.new(file("group_notice.txt")),
          theme_keeper:, links: @engine.opener, server_choice: @server_choice, **use_cases
        )
        # The Show hears the rules' events, and each game as FinishGame
        # finishes it, for Game Over; a store's purchase landing ticks on
        # the offer, after BuyPro has told friend groups of what was earned
        # while Free.
        @cabinet.subscribe(@show)
        use_cases[:finish_game].subscribe(@show)
        entitlement.subscribe(@show.offer)
        @refresh = Refresh.new([-> { @theme_feed&.ask }, -> { groups.refresh }], cabinet: @cabinet, clock: @clock)
        @cabinet.subscribe(@refresh)
        @cabinet.subscribe(GamesLog.new(file(GAMES_LOG), today:, archive: ->(name) { file(name) }))
        @engine.say("each game is logged in #{@engine.path(GAMES_LOG)}")
        @show.group_panel.open if flag?("DOT_POPPER_GROUP_SCREEN")
        @cursor = Presentation::GamepadCursor.centered(@show.layout.whole, style: Style::GAMEPAD, radius: dot_size.radius)
        @cursor = @cursor.show if settings.fake_gamepad?
        @bot = Presentation::Bot.new(Style::BOT) if flag?("DOT_POPPER_AUTOPLAY")
      end

      # A scenario's unlocks and theme, in place of the server's.
      def use_fixture(theme_keeper, use_theme)
        keys = settings["DOT_POPPER_THEME_UNLOCKS"]
        theme_keeper.receive(keys.split(",")) if keys
        key = settings["DOT_POPPER_THEME"]&.to_sym or return

        use_theme.call(key)
      end

      # What the player is assumed to hold before they press anything.
      def starting_input
        return Presentation::InputKind::GAMEPAD if settings.fake_gamepad?

        Presentation::InputKind.starting(touch: platform.touch?)
      end

      # Friend groups on the server in use, each server's token kept apart,
      # so setdef's is never sent to a replacement.
      def groups_session
        url = server_url
        own = url.nil? || url == Network::Server.server_url(settings.env)
        Groups::Session.at(url, store: own ? file("group.txt") : file("group-#{URI(url).host.to_s.downcase}.txt"))
      end

      # What asks whether setdef is gone, and where a license key is: the
      # test build's fake, in this process, sending nothing anywhere; the
      # real server and connectivity checks once setdef's real keys are
      # pinned (Continuity.live?), never in an automated run; and else
      # nothing.
      def watch_for(license, pins)
        unless settings.store_build?
          fake = Continuity::FakeSetdef.new(file("fake_setdef.txt"), mode: Continuity::FakeSetdef.mode(settings.env))
          return Continuity::Watch.new(server: fake, connectivity: fake, gone: @gone, license:, today: settings.today, pins:)
        end
        if Continuity.live? && !settings.automated?
          return Continuity::Watch.new(server: Continuity::SetdefServer.new(Network::Link.new(Network::Server::SERVER_URL)),
                                       connectivity: Continuity::Connectivity.new, gone: @gone, license:, today: settings.today, pins:)
        end

        Continuity::NoWatch.new(gone: @gone, license:)
      end

      # The website's store: its real checkout in the browser, or the test
      # build's, which puts a signed test key on the clipboard.
      def website_store(clipboard, fake:)
        checkout = fake ? FakeCheckout.new(clipboard:) : BrowserCheckout.new(opener: @engine.opener)
        WebsiteStore.new(checkout:, entitlement:, gone: @gone, clipboard:, entered: -> { @watch.start })
      end

      # The feed that reads the server's unlocks, if the game has a server.
      def theme_feed_for(theme_keeper)
        url = server_url or return
        Presentation::ThemeFeed.new(worker: Network::Worker.new(Network::Link.new(url)), theme_keeper:,
                                    store: file("started_on.txt"), clock: settings.utc_clock)
      end
    end
  end
end
