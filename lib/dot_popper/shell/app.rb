# frozen_string_literal: true

module DotPopper
  module Shell
    # The game running in Lota's window. main.rb hands each of Lota's
    # callbacks to one of these methods. Each frame, taps go to the game
    # first, on the frame they happen; then the gamepad cursor moves and
    # the rules move on; then the Show catches up; then the Renderer
    # draws it. Whatever the player presses with, a finger, the mouse, or
    # a gamepad, the Show hears of it, so its words name that press.
    class App
      Style = Presentation::Style
      PLAYTEST_LOG = "games.csv"
      SMALLEST_WINDOW = [400, 320].freeze

      # What the GUI suite's director (test/gui/director.rb) watches as it
      # plays: the rules, the Show, and the game-over pile.
      attr_reader :cabinet, :show, :pile

      # +channel+ is the build's (Build::CHANNEL). It, and not the
      # environment, decides which keys and store this run trusts, and
      # which developer settings (@env) it obeys.
      def initialize(env = ENV, channel: Build::CHANNEL)
        @channel = channel
        @env = Build.settings(env, channel:)
        Automation.guard!(exit_on_attempt: true) if Automation.on?(@env)
        @elapsed = 0.0
        @uptime = 0.0
        @chatter = Presentation::Chatter.quiet(Style::CHATTER)
        @clock = Presentation::FrameClock.start
        @splash = Presentation::Splash.start(calm: flag?("DOT_POPPER_CALM")) unless Presentation::Splash.skipped?(@env)
      end

      def load
        os = ::Lota::System.os
        @dot_size = DotSize.for(os)
        @touch = DotSize.touch?(os)
        @android = os == "Android"
        @mac = os == "OS X"
        @ios = os == "iOS"
        puts "Dot Popper: a dot's radius is #{@dot_size.reason}"
        # With DOT_POPPER_PERF=1: whether this build's Ruby verifies
        # Ed25519, which the packaged-app playthroughs check. Where it
        # does not, setdef is never found gone (Continuity::Watch).
        puts "Dot Popper: Ed25519 #{Continuity::Ed25519.available? ? "verifies" : "does not verify"} the server's test vector" if flag?("DOT_POPPER_PERF")
        @touch ? fill_screen : open_window
        # A desktop's title offers "Full screen" and Quit; a phone's or
        # tablet's game already fills its screen, and leaves by the system.
        @window = if @touch then Presentation::NoWindowControl.new
                  else DesktopWindow.new(exclusive: @env["DOT_POPPER_FULLSCREEN"] == "exclusive")
                  end
        report_renderer
        report_screen
        random = seed ? Random.new(seed) : Random.new
        # Records saved before they were kept by size of screen go to this
        # screen's class.
        legacy = SizeClass.of(screen)
        sizing_store = SaveFile.new(name: "dot_size.txt")
        @cabinet = Cabinet.new(screen, score_record: ScoreRecord.new(SaveFile.new(name: "score_record.txt"), legacy:), random:,
                                 sizing: DotSizing.parse(sizing_store.read))
        puts "Dot Popper: dots are sized to the screen as each game starts" if @cabinet.sizing.sized_to_screen?
        stats_book = StatsBook.new(SaveFile.new(name: "stats.txt"), today:, legacy:)
        notices = NoticeFiles.new(cabinet: File.expand_path("../../..", __dir__),
                                  starts: [File.dirname(File.expand_path($PROGRAM_NAME))]).notices
        achievements = Achievements.new(SaveFile.new(name: "achievements.txt"))
        keeper = StatsKeeper.new(score_record: @cabinet.score_record, stats_book:, achievements:, folder: ->(name) { SaveFile.new(name:) })
        test_build = !Build.store?(@channel)
        @gone = Continuity::Gone.new(SaveFile.new(name: "setdef.txt"))
        pins = trusted_pins
        license = Continuity::License.new(license_store, pins:)
        @watch = watch(license, pins, test_build)
        entitlement = Entitlement.new(forced: Entitlement.forced?(@env, os:), license:, trust: trusted_receipts)
        clipboard = Clipboard.new
        @server_choice = Presentation::ServerChoice.new(SaveFile.new(name: "server.txt"), gone: @gone, clipboard:)
        theme_keeper = Presentation::ThemeKeeper.new(SaveFile.new(name: "themes.txt"), themes: Style::THEMES, entitlement:)
        use_fixture(theme_keeper)
        @theme_keeper = theme_keeper
        theme_keeper.open_by_date(today.call, @gone.days(today.call))
        @theme_feed = theme_feed(theme_keeper)
        @theme_feed&.ask
        @pen = Pen.new(Style, shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        @pen.use(theme_keeper.in_use)
        @speaker = Speaker.new(Style::PATCHES, store: SaveFile.new(name: "sound.txt"), volume: Style::SOUND.volume)
        @speaker.use(theme_keeper.in_use)
        @splash = @splash.with(sounding: !@speaker.muted?) if @splash
        storefront = Presentation::Storefront.for(
          os, entitlement:, channel: @channel,
              native: native_store(os),
              fake: Presentation::FakeStore.new(SaveFile.new(name: "fake_store.txt"), fails: Presentation::FakeStore.failure(@env)),
              website: ->(fake:) { website_store(license, clipboard, fake:) }
        )
        games = free_games(entitlement, metered: storefront.offered? && player?)
        groups = groups_session
        @show = Presentation::Show.new(groups:, cabinet: @cabinet, layout:, sounds: @speaker, radius: @dot_size.radius,
                                       random:, calm: flag?("DOT_POPPER_CALM"),
                                       tutor: Presentation::Tutor.new(SaveFile.new(name: "taught.txt"),
                                                                    times: Style::LESSON.times),
                                       haptics: Haptics.for(os), clipboard:, notices:,
                                       sharing: Presentation::SheetSharing.for(os, opener: UrlOpener.new),
                                       stats_book:, achievements:, keeper:, sizing_store:, input: starting_input, measure: FontMeasure.new(@pen.fonts),
                                       window: @window,
                                       tutorial_flag: Presentation::TutorialFlag.new(
                                         SaveFile.new(name: "tutorial.txt"), mode: Presentation::TutorialFlag.mode(@env)
                                       ),
                                       group_notice: Presentation::GroupNotice.new(SaveFile.new(name: "group_notice.txt")),
                                       entitlement:, theme_keeper:, storefront:, games:, links: UrlOpener.new,
                                       server_choice: @server_choice)
        storefront.connect
        @watch.start
        @cabinet.subscribe(PlaytestLog.new(SaveFile.new(name: PLAYTEST_LOG), today:,
                                        archive: ->(name) { SaveFile.new(name:) }))
        puts "Dot Popper: each game is logged in #{File.join(::Lota::Filesystem.save_directory, PLAYTEST_LOG)}"
        @pile = Pile.new(flag?("DOT_POPPER_CALM") ? Style::CALM_PILE : Style::PILE)
        @cabinet.subscribe(@pile)
        @gamepads = Gamepads.new(pretend: fake_gamepad?)
        @tilting = tilting
        @cabinet.subscribe(@tilting)
        @dragging = Dragging.new(pile: @pile, show: @show, style: flag?("DOT_POPPER_CALM") ? Style::CALM_GRAB : Style::GRAB)
        @cabinet.subscribe(@dragging)
        @fake_drag = Presentation::FakeDrag.parse(@env["DOT_POPPER_FAKE_DRAG"])
        @sparks = Sparks.new(Style)
        @bloom = Bloom.new(@pen, Style::BLOOM)
        @renderer = Renderer.new(@show, @pen, pile: @pile, sparks: @sparks, bloom: @bloom,
                                             diagnostic: flag?("DOT_POPPER_DIAGNOSTIC_COLORS"))
        @renderer.prepare
        @show.group_panel.open if flag?("DOT_POPPER_GROUP_SCREEN")
        @input = Presentation::InputRouter.new
        @buttons = Presentation::GamepadButtons.new
        @trigger = Presentation::Trigger.released
        @cursor = Presentation::GamepadCursor.centered(@show.layout.whole, style: Style::GAMEPAD,
                                                       radius: @dot_size.radius)
        @cursor = @cursor.show if fake_gamepad?
        @pad_held = []
        @autopilot = Presentation::Autopilot.new(Style::AUTOPILOT) if flag?("DOT_POPPER_AUTOPLAY")
        @shots = Presentation::ShotSchedule.parse(@env["DOT_POPPER_SHOTS"])
        @quit_after = Float(@env.fetch("DOT_POPPER_QUIT_AFTER", ""), exception: false)
        @frames = Presentation::FrameMeter.start(5) if flag?("DOT_POPPER_PERF")
        @cabinet.subscribe { happened(it.class.name.split("::").last) } if @frames
      end

      # Lota's frame, which Lota measured as +measured+ seconds: the game
      # moves on by the time between frames starting to draw (FrameClock).
      def tick(measured)
        @clock, seconds = @clock.tick(::Lota::Timer.time, measured)
        update(seconds)
      end

      def update(seconds)
        measure(seconds)
        @uptime += seconds
        seconds = seconds.clamp(0.0, Rules::LONGEST_FRAME)
        if @splash
          @splash.notes(seconds).each { @speaker.play(:tick, pitch: it.pitch) }
          @splash = @splash.advance(seconds)
        end
        @splash = nil if @splash&.over?
        moved = @cursor.update(seconds, read_with_stick(seconds))
        @show.input = Presentation::InputKind::GAMEPAD unless moved == @cursor
        @cursor = moved
        if @autopilot
          x, y = @autopilot.update(seconds, @cabinet, @show)
          tap(x, y) if x
        end
        @cabinet.update(seconds)
        @show.update(seconds)
        @theme_feed&.update
        follow_watch
        use_theme
        point_the_mouse
        repeat_keys
        @tilting.update(seconds)
        fake_drag
        @dragging.move(:gamepad, @cursor.x, @cursor.y) if @pad_held.any?
        @dragging.update(seconds)
        @pile.update(seconds)
        @sparks.update(seconds, @show.effects)
        development(seconds)
      end

      def draw
        @clock = @clock.drawing(::Lota::Timer.time)
        @renderer.draw(@cursor, @splash)
      end

      def mouse_pressed(x, y, button, istouch)
        return if chattered?(x, y, button, istouch)
        return skip_splash if @splash

        @cursor = @cursor.hide(x, y)
        tap = heard(@input.mouse_pressed(x, y, button, istouch))
        @show.pointer_at(tap.x, tap.y) if tap
        press(:mouse, tap)
      end

      # A motion counts as using the mouse only once it has gone far
      # enough (MouseTravel); a drag follows it either way, and so does
      # what the mouse is over, for its hover.
      def mouse_moved(x, y, istouch)
        point = @input.mouse_moved(x, y, istouch) or return
        @show.pointer_at(point.x, point.y)
        @travel = nil if window_settling?
        @travel = (@travel || Presentation::MouseTravel.start).moved(x, y)
        if @travel.deliberate?
          @cursor = @cursor.hide(x, y)
          heard(point)
        end
        @show.drag_scroll(:mouse, point.y)
        @dragging.move(:mouse, point.x, point.y)
      end

      def mouse_released(x, y, button, istouch)
        return if released_chatter?(button, istouch)

        point = @input.mouse_released(x, y, button, istouch) or return
        @show.let_go(:mouse)
        @dragging.release(:mouse, point.x, point.y)
      end

      def touch_pressed(id, x, y, devicetype, mouse)
        return skip_splash if @splash

        @cursor = @cursor.hide
        press(id, heard(@input.touch_pressed(id, x, y, devicetype, mouse)))
      end

      def touch_moved(id, x, y, devicetype, mouse)
        point = heard(@input.touch_moved(id, x, y, devicetype, mouse))
        return unless point

        @show.drag_scroll(id, point.y)
        @dragging.move(id, point.x, point.y)
      end

      def touch_released(id, x, y, devicetype, mouse)
        point = @input.touch_released(id, x, y, devicetype, mouse) or return
        @show.let_go(id)
        @dragging.release(id, point.x, point.y)
      end

      # The window lost focus or got it back. A finger or button let go
      # meanwhile is never heard, so the pile's dots are let go now, and
      # so is "Clear my stats…", and no release is waited for to drop.
      def focus(focused)
        return if focused

        @dragging.drop
        @chatter = @chatter.let_go
        @show.let_go_of_everything
        @show.pointer_gone
      end

      # The mouse left the window, or came back into it. Once it has
      # left, it is over no button; back in, its next motion says where.
      def mouse_focus(focused)
        @show.pointer_gone unless focused
      end

      # Whether the mouse pointer is the system's pointing hand, as it is
      # while the mouse is over a button.
      def pointing_hand? = @hand == true

      # A gamepad button went down (Lota 0.1.3 and newer). Any button shows
      # the cursor; GamepadButtons says what each one asks for.
      def gamepad_pressed(button)
        return skip_splash if @splash

        gamepad_used
        case @buttons.intent(button)
        in :press then gamepad_down(:a)
        in :start then @show.start
        in :y then y_pressed
        in :leave then @show.back || leave_title
        in :x | :lb | :rb | :select => name then @show.pad(name)
        in nil then nil
        end
      end

      # Y: on the title and Settings a button of its own, and Game Over's
      # Share my score.
      def y_pressed
        @show.game_over? || @show.sharing? ? @show.share : @show.pad(:y)
      end

      # A gamepad button came up. Letting go of A ends its press, which on
      # Game Over throws a dragged dot, or goes on, as a click does; letting
      # go of Y ends a hold of "Clear my stats…".
      def gamepad_released(button)
        case @buttons.intent(button)
        in :press then gamepad_up(:a)
        in :y then @show.let_go(:y)
        in :start then @show.let_go(:start)
        else nil
        end
      end

      # A gamepad's axis moved. The right trigger presses and lets go as A
      # does; the sticks are read each frame instead (Gamepads).
      def gamepad_axis(axis, value)
        return left_trigger(value) if axis.to_s == "triggerleft"
        return unless axis.to_s == "triggerright"
        return skip_splash if @splash && value.to_f > 0.5

        was_held = @trigger.held
        @trigger = @trigger.pull(value.to_f, Style::GAMEPAD)
        return gamepad_up(:trigger) if was_held && !@trigger.held
        return unless @trigger.pressed

        gamepad_used
        gamepad_down(:trigger)
      end

      # The left trigger, as a button, opens Friend groups on Home (LT).
      def left_trigger(value)
        @left_trigger = (@left_trigger || Presentation::Trigger.released).pull(value.to_f, Style::GAMEPAD)
        return unless @left_trigger.pressed

        gamepad_used
        @show.pad(:lt)
      end

      # A controller was plugged in, or was there when the game started.
      def gamepad_added(joystick) = @gamepads.added(joystick)

      # A controller was unplugged: forget it, and let its trigger go.
      def gamepad_removed(joystick)
        @gamepads.removed(joystick)
        @trigger = Presentation::Trigger.released
        @pad_held.dup.each { gamepad_up(it) }
      end

      # The mouse wheel turned +y+ notches, up when positive.
      def wheel_moved(y) = @show.wheel_scroll(y)

      def key_pressed(key)
        return skip_splash if @splash

        @show.keyboard_used(@mac ? "\u2318B" : "Ctrl+B") unless @touch
        return if key == :v && paste_chord? && @show.paste_shortcut
        # Ctrl+B or Cmd+B buys on the offer: a chord, so no press that means
        # continue or back, and no letter of a typed license key, buys.
        return if key == :b && paste_chord? && @show.buy_shortcut
        return if @show.type_key(key)
        return @speaker.toggle_mute if key == :m
        return @show.how_to_play if key == :h
        return @show.open_credits if key == :c && @show.settings?
        return if @show.scroll_key(key)
        # Enter or Space presses the screen's main button, on any device;
        # Alt+Enter (Cmd+Enter on a Mac) is fullscreen's instead.
        return @show.primary if PRIMARY_KEYS.include?(key) && !(key != :space && fullscreen_chord?)
        # Escape, which Android's Back arrives as, goes back from the
        # Stats screen or Game Over first, on any device.
        return if key == :escape && @show.back
        # On the title Android's Back leaves the app, as Back on an app's
        # first screen does; in a game it does nothing, so a stray edge
        # swipe never throws a game away.
        return ::Lota::Event.quit if key == :escape && @android && @show.home?
        # A tablet's keyboard neither quits the app nor takes it out of
        # fullscreen: iOS apps are left by the system, never by the app.
        return if @touch

        case key
        when :escape then ::Lota::Event.quit
        when :f11 then toggle_fullscreen
        when :return, :kpenter then toggle_fullscreen if fullscreen_chord?
        end
      end

      PRIMARY_KEYS = %i[return kpenter space].freeze

      # The window changed size, or moved to a screen of another density.
      # For a moment after the window opens or changes size, the pointer
      # seems to move under a still mouse, as the window moves under it
      # (Windows sends several such motions as it grows a window to the
      # display's scale), so no motion then takes the words to the mouse.
      SETTLE = 0.5

      def window_settling? = @uptime < (@settled_at || SETTLE)

      def resize
        @settled_at = @uptime.to_f + SETTLE
        return unless @show

        happened("a resize")
        report_screen
        @pen.refresh
        @sparks.refresh
        @bloom.refresh
        @cabinet.screen = screen
        @show.resize(layout, @cabinet.field)
        # The heap keeps the finished game's dots, and their radius.
        game = @cabinet.game
        @pile.refit(game ? Field.new(screen.width, screen.height, game.field.radius) : @cabinet.field)
        @renderer.prepare
        @cursor = @cursor.refit(@show.layout.whole)
      end

      private

      # A press ends the setdef splash, and goes no further: it is never
      # heard by the game, so it can touch nothing.
      def skip_splash = @splash = @splash.skip

      # The gamepad's left stick and d-pad for the cursor, which on the
      # Credits screen scroll it instead and leave the cursor at rest.
      def read_with_stick(seconds)
        stick = @gamepads.stick
        @show.stick_scroll(@gamepads.right_stick, seconds)
        return stick unless @show.credits?

        @show.stick_scroll(stick, seconds)
        Presentation::Stick.rest
      end

      # Held arrow and Page keys go on scrolling the lists, and the only
      # places the keyboard asks for repeats.
      def repeat_keys
        reading = @show.scrolling?
        return if reading == @reading

        @reading = reading
        ::Lota::Keyboard.key_repeat = reading
      end

      # A scenario's unlocks and theme, in place of the server's.
      def use_fixture(theme_keeper)
        keys = @env["DOT_POPPER_THEME_UNLOCKS"]
        theme_keeper.receive(keys.split(",")) if keys
        key = @env["DOT_POPPER_THEME"]&.to_sym or return

        Style::THEMES.find { it.key == key }&.then { theme_keeper.use(it) }
      end

      # The server friend groups and themes use: setdef's, or while setdef
      # is gone, a replacement the player chose (Presentation::ServerChoice),
      # or none in an automated run.
      def server_url
        own = Groups::Settings.server_url(@env) or return
        @server_choice.server_url(own)
      end

      # Friend groups on the server in use, each server's token kept apart,
      # so setdef's is never sent to a replacement.
      def groups_session
        require "uri"
        url = server_url
        own = url.nil? || url == Groups::Settings.server_url(@env)
        Groups::Session.at(url, store: own ? SaveFile.new(name: "group.txt") : SaveFile.new(name: "group-#{URI(url).host.to_s.downcase}.txt"))
      end

      # The keys this run trusts, decided by the build alone: the test
      # keys in a test build, setdef's in a store build, whatever the
      # environment says.
      # Where the license key is kept: license.txt, except in an app
      # store's build, which never reads that file (so a key left on disk
      # grants nothing and is never sent) and keeps nothing in its place.
      def license_store = Build.license_keys?(@channel) ? SaveFile.new(name: "license.txt") : ScoreRecord::Memory.new

      def trusted_pins = Build.store?(@channel) ? Continuity::PINNED : Continuity::TEST_PINS

      # Whose receipts prove Pro, by the channel alone: in a test build only
      # the fake store's; in the Microsoft Store's build Windows' word,
      # which comes only down the store helper's pipe; in any other store
      # build the signed receipts of Apple and Google.
      def trusted_receipts
        return Receipt::TEST unless Build.store?(@channel)

        @channel == Presentation::Storefront::MICROSOFT_STORE ? Receipt::MICROSOFT_STORE : Receipt::STORES
      end

      # The native port: on a phone the app's host, by URL and answer file;
      # on a computer sold through its own store, the store helper shipped
      # in the app, by its pipe (StoreHelper). Which one a build uses is
      # Storefront.for's choice, by the channel.
      def native_store(os)
        if Presentation::Storefront::HELPER_CHANNELS.value?(os)
          return StoreHelper.new(StoreHelper.find(os, starts: [__dir__, File.dirname(File.expand_path($PROGRAM_NAME))]),
                                 automated: Automation.on?(@env))
        end

        Presentation::NativeStore.new(opener: UrlOpener.new, answers: StoreAnswers.in_save_folder)
      end

      # What asks whether setdef is gone, and where a license key is: the
      # test build's fake, in this process, sending nothing anywhere; the
      # real server and connectivity checks once setdef's real keys are
      # pinned (Continuity.live?), never in an automated run; and else
      # nothing.
      def watch(license, pins, test_build)
        if test_build
          fake = Continuity::FakeSetdef.new(SaveFile.new(name: "fake_setdef.txt"), mode: Continuity::FakeSetdef.mode(@env))
          Continuity::Watch.new(server: fake, connectivity: fake, gone: @gone, license:, today:, pins:)
        elsif Continuity.live? && !Automation.on?(@env)
          Continuity::Watch.new(server: Continuity::SetdefServer.new(Groups::Link.new(Groups::Settings::SERVER_URL)),
                                connectivity: Continuity::Connectivity.new, gone: @gone, license:, today:, pins:)
        else
          Continuity::NoWatch.new(gone: @gone, license:)
        end
      end

      # The website's store: its real checkout in the browser, or the test
      # build's, which puts a signed test key on the clipboard.
      def website_store(license, clipboard, fake:)
        checkout = fake ? Presentation::FakeCheckout.new(clipboard:) : Presentation::BrowserCheckout.new(opener: UrlOpener.new)
        Presentation::WebsiteStore.new(checkout:, license:, gone: @gone, clipboard:, entered: -> { @watch.start })
      end

      # Takes up a finished check of setdef: back again, a chosen server is
      # forgotten; gone long enough, themes open by their dates.
      def follow_watch
        answer = @watch.update or return
        @server_choice.forget if answer == :here
        @theme_keeper.open_by_date(today.call, @gone.days(today.call))
      end

      # The feed that reads the server's unlocks, if the game has a server.
      def theme_feed(theme_keeper)
        url = server_url or return
        Presentation::ThemeFeed.new(worker: Groups::Worker.new(Groups::Link.new(url)), theme_keeper:,
                                    store: SaveFile.new(name: "started_on.txt"), clock: utc_clock)
      end

      # Puts on the Show's look if it has changed (Presentation::ThemeKeeper),
      # which is only ever between games.
      def use_theme
        return unless @pen.use(@show.in_use)

        @renderer.prepare
        @speaker.use(@show.in_use)
      end

      # A press at +x+, +y+, by +by+ (a finger's id, :mouse, :gamepad, or
      # the autopilot), which its release names too.
      def tap(x, y, by = :autopilot) = @show.tap(x, y, by:)

      # Whether a mouse press is its switch chattering (Presentation::
      # Chatter), to be dropped, wherever it lands, as its release will
      # be. Its clock is the frames' time, unclamped: the real time in
      # play, and the scenario's in the GUI suite.
      def chattered?(x, y, button, istouch)
        return false if istouch

        @chatter, chatter = @chatter.press(button, x.to_f, y.to_f, at: @uptime)
        chatter
      end

      def released_chatter?(button, istouch)
        return false if istouch

        @chatter, chatter = @chatter.release(button)
        chatter
      end

      # Tells the Show what made +tap+, if anything did, so its words name
      # that press. Returns +tap+.
      # A finger starts the mouse's travel afresh, as the gamepad does, so
      # only a new, deliberate move takes the words back to the mouse.
      def heard(tap)
        @travel = nil if tap && tap.kind != Presentation::InputKind::MOUSE
        @show.input = tap.kind if tap
        tap
      end

      # The gamepad was used: its cursor shows, and the words name its
      # buttons.
      def gamepad_used
        @travel = Presentation::MouseTravel.start
        @cursor = @cursor.show
        @show.input = Presentation::InputKind::GAMEPAD
      end

      # The system's pointing hand while the mouse is over a button, and
      # its arrow otherwise; only the mouse hovers (Show#hovered). The
      # pointer changes only as that does.
      def point_the_mouse
        hand = !@show.hovered.nil?
        return if hand == (@hand || false)

        @hand = hand
        ::Lota::Mouse.cursor = hand ? hand_cursor : nil
      end

      # The pointing hand, once fetched; nil where the system has no
      # pointer to change, as on a touchscreen.
      def hand_cursor
        return unless ::Lota::Mouse.cursor_supported?

        @hand_cursor ||= ::Lota::Mouse.system_cursor(:hand)
      end

      def starting_input
        return Presentation::InputKind::GAMEPAD if fake_gamepad?

        Presentation::InputKind.starting(touch: @touch)
      end

      # A mouse button or finger went down, as +tap+ (or nil for none). It
      # counts at once, unless the Show waits for its release, on Game
      # Over, where it may become a drag.
      def press(key, tap)
        return unless tap
        return tap(tap.x, tap.y, key) unless @show.waits_for_release?(tap.x, tap.y)

        @dragging.press(key, tap.x, tap.y)
      end

      # DOT_POPPER_FAKE_DRAG's drag, a step each frame once Game Over has
      # been shown long enough. With DOT_POPPER_FAKE_GAMEPAD, the gamepad
      # makes it: the cursor goes where the drag is, and A holds the dot.
      def fake_drag
        return unless @fake_drag && @show.game_over?

        width, height = ::Lota::Graphics.dimensions
        @fake_drag.step(@show.game_over.at, @show.now, width, height) do |action, x, y|
          x, y = nearest_ball(x, y) if action == :press
          unless action == :move
            puts "Dot Popper: the fake drag #{action == :press ? "takes" : "throws"} a dot at #{x.round}, #{y.round}, " \
                 "#{@elapsed.round(1)} seconds in"
          end
          fake_gamepad? ? fake_pad(action, x, y) : @dragging.public_send(action, :fake, x, y)
        end
      end

      def fake_pad(action, x, y)
        @cursor = @cursor.at(x, y).show
        case action
        in :press then gamepad_down(:a)
        in :release then gamepad_up(:a)
        in :move then nil
        end
      end

      def fake_gamepad? = flag?("DOT_POPPER_FAKE_GAMEPAD")

      # A or the right trigger, +source+, went down: a press at the cursor,
      # as a mouse button's. On Game Over it waits to be let go, as a
      # click does, and held on a dot it drags it; elsewhere it counts at
      # once. A second source held with the first adds nothing.
      def gamepad_down(source)
        @pad_held << source
        press(:gamepad, @input.gamepad_pressed(@cursor)) if @pad_held.size == 1
      end

      # A or the right trigger let go: once neither is held, the press ends
      # where the cursor is.
      def gamepad_up(source)
        return unless @pad_held.delete(source) && @pad_held.empty?

        point = @input.gamepad_released(@cursor)
        @show.let_go(:gamepad)
        @dragging.release(:gamepad, point.x, point.y)
      end

      # The window, sized in graphics units: where the system's window
      # coordinates are pixels (Windows at 200%), its size and smallest
      # size are scaled to them, so a scaled display gets the same window.
      def open_window
        width, = ::Lota::Window.mode
        per_unit = [width.to_f / ::Lota::Graphics.width, 1.0].max
        size = Style::WINDOW.mode_for(*::Lota::Window.desktop_dimensions, @dot_size.radius, per_unit:, smallest: SMALLEST_WINDOW,
                                                                                           wanted: window_size)
        ::Lota::Window.set_mode(size[0], size[1], resizable: true, centered: true, minwidth: size[2], minheight: size[3])
      end

      # A phone or tablet's window already covers the screen; fullscreen
      # hides the status bar over it and, on iOS, makes a swipe from an
      # edge ask twice before it leaves the game (SDL's UIKit view
      # controller), so a tap near the edge stays a tap.
      def fill_screen = ::Lota::Window.set_fullscreen(true, :desktop)

      # B on the title: asks, then quits on a second press, as Escape quits
      # from the keyboard. iOS apps are left by the system, never by the app.
      def leave_title
        ::Lota::Event.quit if !@ios && @show.ask_to_quit == :quit
      end

      # Whether Ctrl or Cmd is held, which makes V paste.
      def paste_chord? = ::Lota::Keyboard.down?(:lctrl, :rctrl, :lgui, :rgui)

      # Whether Alt or Cmd is held, which makes Enter switch fullscreen.
      def fullscreen_chord? = ::Lota::Keyboard.down?(:lalt, :ralt, :lgui, :rgui)

      # F11 or Alt+Enter, as the title's "Full screen" (DesktopWindow).
      def toggle_fullscreen
        happened("a fullscreen switch")
        @window.toggle_fullscreen
      end

      # The window as a field of dots at the usual size; the game sizes a
      # game's dots on it as the player chose (DotSizing).
      def screen = @dot_size.field(*::Lota::Graphics.dimensions)

      # The graphics renderer LÖVE chose, as Vulkan, OpenGL ES, or Metal,
      # its version, and the GPU's maker and name.
      def report_renderer
        name, version, vendor, device = ::Lota::Graphics.renderer_info
        puts "Dot Popper: renderer #{name} #{version} / #{vendor} / #{device}"
      end

      # One line on what the window is (Presentation::ScreenReport), to
      # compare a real device's run with an SDL test program's on it.
      def report_screen
        width, height, flags = ::Lota::Window.mode
        mode_flags = %i[fullscreen fullscreentype highdpi usedpiscale].filter_map do |name|
          [name, flags.public_send(name)] if flags.respond_to?(name)
        end.to_h
        report = Presentation::ScreenReport.new(
          units: ::Lota::Graphics.dimensions, pixels: ::Lota::Graphics.pixel_dimensions,
          dpi_scale: ::Lota::Graphics.dpi_scale, native: ::Lota::Window.native_dpi_scale,
          safe: ::Lota::Window.safe_area, mode: [width, height, mode_flags]
        )
        puts "Dot Popper: #{report}"
      end

      def layout
        width, height = ::Lota::Graphics.dimensions
        x, y, safe_width, safe_height = ::Lota::Window.safe_area
        safe = Presentation::Rect.new(x:, y:, width: safe_width, height: safe_height)
        safe = Presentation::Rect.new(x: 0, y: 0, width:, height:) unless safe.width.to_f.positive?
        Presentation::Layout.new(width:, height:, safe:, style: Style::LAYOUT)
      end

      # DOT_POPPER_WINDOW=400x850: a window of that size, for checking a
      # narrow screen; nil without it.
      def window_size
        width, height = @env.fetch("DOT_POPPER_WINDOW", "").split("x", 2).map { Integer(it, exception: false) }
        [[width, SMALLEST_WINDOW[0]].max, [height, SMALLEST_WINDOW[1]].max] if width && height
      end

      # Whether someone is playing, not a machine: not the autoplay bot,
      # and not a GUI scenario, unless it sets DOT_POPPER_FREE_GAMES to try
      # the limit.
      def player?
        return true if Build.store?(@channel)
        return false if flag?("DOT_POPPER_AUTOPLAY")

        @env.fetch("DOT_POPPER_SCENARIO", "").empty? || @env.key?("DOT_POPPER_FREE_GAMES")
      end

      # The games a free player has left, counted where Pro
      # can be bought, as #player? allows. DOT_POPPER_FREE_GAMES=n starts a
      # new save with n games in the bank and n for the day, to try the
      # limit.
      def free_games(entitlement, metered:, store: SaveFile.new(name: "games.txt"))
        start = Integer(@env.fetch("DOT_POPPER_FREE_GAMES", ""), exception: false)
        FreeGames.new(store, today:, entitlement:, metered:,
                      **(start ? { bank: start, daily: start } : {}))
      end

      # The moment the server's dates are told from, in UTC: now, or
      # midnight UTC of DOT_POPPER_TODAY's day.
      def utc_clock
        pretend = Date.iso8601(@env.fetch("DOT_POPPER_TODAY", ""))
        -> { Time.utc(pretend.year, pretend.month, pretend.day) }
      rescue Date::Error
        -> { Time.now.utc }
      end

      # The player's local date, or DOT_POPPER_TODAY's, to try another
      # day's goal or a streak.
      def today
        pretend = Date.iso8601(@env.fetch("DOT_POPPER_TODAY", ""))
        -> { pretend }
      rescue Date::Error
        -> { Date.today }
      end

      # Playing with the game-over pile: by the accelerometer, or
      # DOT_POPPER_FAKE_TILT's steady reading in its place, and by any
      # gamepad's right stick.
      def tilting
        fake = Presentation::Reading.parse(@env["DOT_POPPER_FAKE_TILT"])
        Tilting.new(pile: @pile, gamepads: @gamepads,
                    accelerometer: fake ? FakeAccelerometer.new(steady: fake) : Accelerometer.new,
                    style: flag?("DOT_POPPER_CALM") ? Style::CALM_TILT : Style::TILT, turns: @touch)
      end

      # The middle of the pile's ball nearest +x+, +y+, or that point with
      # no pile.
      def nearest_ball(x, y)
        dot = @pile.stack&.dots&.min_by { Math.hypot(it.x - x, it.y - y) }
        dot ? [dot.x, dot.y] : [x, y]
      end

      def flag?(name) = @env[name] == "1"
      def seed = Integer(@env.fetch("DOT_POPPER_SEED", ""), exception: false)

      # The development hooks main.rb describes.
      def development(seconds)
        before = @elapsed
        @elapsed += seconds
        @shots.due(before, @elapsed).each { screenshot(it) }
        ::Lota::Event.quit if @quit_after && @elapsed >= @quit_after
      end

      # With DOT_POPPER_PERF=1, prints how smoothly the game ran every five
      # seconds, and every frame slow enough to notice with what was going
      # on, from each frame's real time.
      def measure(seconds)
        return unless @frames

        gcs = [GC.stat(:major_gc_count), GC.stat(:minor_gc_count)]
        if @gcs && Presentation::SlowFrame.slow?(seconds)
          puts "Dot Popper: #{slow_frame(seconds, gcs).report}"
        end
        @gcs = gcs
        @frames, report = @frames.record(seconds)
        puts "Dot Popper: #{report}" if report
      end

      def slow_frame(seconds, gcs)
        recent, at = @recent
        Presentation::SlowFrame.new(seconds:, screen: screen_name, recent:, since: at && (@elapsed - at),
                                    major_gcs: gcs[0] - @gcs[0], minor_gcs: gcs[1] - @gcs[1])
      end

      def screen_name
        if @show.stats? then "Stats"
        elsif @show.tutorial? then "the tutorial"
        elsif @show.playing? then "a game"
        elsif @show.game_over? then "Game Over"
        else "Home"
        end
      end

      # Notes the latest thing to happen, for a slow frame's report.
      def happened(what)
        @recent = [what, @elapsed] if @frames
      end

      def screenshot(number)
        name = "shot-#{number}.png"
        ::Lota::Graphics.capture_screenshot(name)
        puts "Dot Popper: screenshot #{File.join(::Lota::Filesystem.save_directory, name)}"
      end
    end
  end
end
