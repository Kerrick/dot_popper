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
      Look = Presentation::Look
      PLAYTEST_LOG = "rounds.csv"
      SMALLEST_WINDOW = [400, 320].freeze

      # What the GUI suite's director (test/gui/director.rb) watches as it
      # plays: the rules, the Show, and the game-over pile.
      attr_reader :game, :show, :pile

      def initialize(env = ENV)
        @env = env
        @elapsed = 0.0
      end

      def load
        os = ::Lota::System.os
        @dot_size = DotSize.for(os)
        @touch = DotSize.touch?(os)
        @android = os == "Android"
        puts "Dot Popper: a dot's radius is #{@dot_size.reason}"
        @touch ? fill_screen : open_window
        report_renderer
        report_screen
        random = seed ? Random.new(seed) : Random.new
        # Bests saved before they were kept by size of screen go to this
        # screen's class.
        legacy = SizeClass.of(screen)
        sizing_store = SaveFile.new(name: "dot_size.txt")
        @game = Game.new(screen, best: BestScore.new(SaveFile.new(name: "best_score.txt"), legacy:), random:,
                                 sizing: DotSizing.parse(sizing_store.read))
        puts "Dot Popper: dots are sized to the screen as each round starts" if @game.sizing.sized_to_screen?
        lifetime = Lifetime.new(SaveFile.new(name: "lifetime.txt"), today:, legacy:)
        notices = NoticeFiles.new(game: File.expand_path("../../..", __dir__),
                                  starts: [File.dirname(File.expand_path($PROGRAM_NAME))]).notices
        keeper = RecordKeeper.new(best: @game.best, lifetime:, folder: ->(name) { SaveFile.new(name:) })
        @pen = Pen.new(Look, shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        @speaker = Speaker.new(Look::PATCHES, store: SaveFile.new(name: "sound.txt"), volume: Look::SOUND.volume)
        @show = Presentation::Show.new(game: @game, layout:, sounds: @speaker, radius: @dot_size.radius,
                                       random:, calm: flag?("DOT_POPPER_CALM"),
                                       tutor: Presentation::Tutor.new(SaveFile.new(name: "taught.txt"),
                                                                    times: Look::LESSON.times),
                                       haptics: Haptics.for(os), clipboard: Clipboard.new, notices:,
                                       lifetime:, keeper:, sizing_store:, input: starting_input, measure: FontMeasure.new(@pen.fonts),
                                       hint: -> { @tilting&.hint&.for(@show.input) })
        @game.subscribe(PlaytestLog.new(SaveFile.new(name: PLAYTEST_LOG), today:,
                                        archive: ->(name) { SaveFile.new(name:) }))
        puts "Dot Popper: each round is logged in #{File.join(::Lota::Filesystem.save_directory, PLAYTEST_LOG)}"
        @pile = Pile.new(flag?("DOT_POPPER_CALM") ? Look::CALM_PILE : Look::PILE)
        @game.subscribe(@pile)
        @gamepads = Gamepads.new(pretend: fake_gamepad?)
        @tilting = tilting(os)
        @game.subscribe(@tilting)
        @dragging = Dragging.new(pile: @pile, show: @show, look: flag?("DOT_POPPER_CALM") ? Look::CALM_GRAB : Look::GRAB)
        @game.subscribe(@dragging)
        @fake_drag = Presentation::FakeDrag.parse(@env["DOT_POPPER_FAKE_DRAG"])
        @sparks = Sparks.new(Look)
        @bloom = Bloom.new(@pen, Look::BLOOM)
        @renderer = Renderer.new(@show, @pen, pile: @pile, sparks: @sparks, bloom: @bloom, tilting: @tilting,
                                             diagnostic: flag?("DOT_POPPER_DIAGNOSTIC_COLORS"))
        @renderer.prepare
        @input = Presentation::InputRouter.new
        @buttons = Presentation::GamepadButtons.new
        @trigger = Presentation::Trigger.released
        @cursor = Presentation::GamepadCursor.centered(@show.layout.whole, look: Look::GAMEPAD,
                                                       radius: @dot_size.radius)
        @cursor = @cursor.show if fake_gamepad?
        @pad_held = []
        @autopilot = Presentation::Autopilot.new(Look::AUTOPILOT) if flag?("DOT_POPPER_AUTOPLAY")
        @shots = Presentation::ShotSchedule.parse(@env["DOT_POPPER_SHOTS"])
        @quit_after = Float(@env.fetch("DOT_POPPER_QUIT_AFTER", ""), exception: false)
        @frames = Presentation::FrameMeter.start(5) if flag?("DOT_POPPER_PERF")
        @game.subscribe { happened(it.class.name.split("::").last) } if @frames
      end

      def update(seconds)
        measure(seconds)
        seconds = seconds.clamp(0.0, Rules::LONGEST_FRAME)
        moved = @cursor.update(seconds, read_with_stick(seconds))
        @show.input = Presentation::InputKind::GAMEPAD unless moved == @cursor
        @cursor = moved
        if @autopilot
          x, y = @autopilot.update(seconds, @game, @show)
          tap(x, y) if x
        end
        @game.update(seconds)
        @show.update(seconds)
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

      def draw = @renderer.draw(@cursor)

      def mouse_pressed(x, y, button, istouch)
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
        @travel = (@travel || Presentation::MouseTravel.start).moved(x, y)
        if @travel.deliberate?
          @cursor = @cursor.hide(x, y)
          heard(point)
        end
        @show.drag_credits(:mouse, point.y)
        @dragging.move(:mouse, point.x, point.y)
      end

      def mouse_released(x, y, button, istouch)
        point = @input.mouse_released(x, y, button, istouch) or return
        @show.let_go(:mouse)
        @dragging.release(:mouse, point.x, point.y)
      end

      def touch_pressed(id, x, y, devicetype, mouse)
        @cursor = @cursor.hide
        press(id, heard(@input.touch_pressed(id, x, y, devicetype, mouse)))
      end

      def touch_moved(id, x, y, devicetype, mouse)
        point = heard(@input.touch_moved(id, x, y, devicetype, mouse))
        return unless point

        @show.drag_credits(id, point.y)
        @dragging.move(id, point.x, point.y)
      end

      def touch_released(id, x, y, devicetype, mouse)
        point = @input.touch_released(id, x, y, devicetype, mouse) or return
        @show.let_go(id)
        @dragging.release(id, point.x, point.y)
      end

      # The window lost focus or got it back. A finger or button let go
      # meanwhile is never heard, so the pile's dots are let go now, and
      # so is "Clear my records…".
      def focus(focused)
        return if focused

        @dragging.drop
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
        gamepad_used
        case @buttons.intent(button)
        in :press then gamepad_down(:a)
        in :start then @show.start
        in :share then @show.records? ? @show.clear_or_undo(:y) : @show.share
        in :records then @show.records? ? @show.open_credits : (@show.open_records if @show.records_offered?)
        in :leave then @show.back
        in :mute then @speaker.toggle_mute
        in :sizing then @show.toggle_sizing
        in nil then nil
        end
      end

      # A gamepad button came up. Letting go of A ends its press, which on
      # Game Over throws a dragged dot, or goes on, as a click does; letting
      # go of Y ends a hold of "Clear my records…".
      def gamepad_released(button)
        case @buttons.intent(button)
        in :press then gamepad_up(:a)
        in :share then @show.let_go(:y)
        else nil
        end
      end

      # A gamepad's axis moved. The right trigger presses and lets go as A
      # does; the sticks are read each frame instead (Gamepads).
      def gamepad_axis(axis, value)
        return unless axis.to_s == "triggerright"

        was_held = @trigger.held
        @trigger = @trigger.pull(value.to_f, Look::GAMEPAD)
        return gamepad_up(:trigger) if was_held && !@trigger.held
        return unless @trigger.pressed

        gamepad_used
        gamepad_down(:trigger)
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
      def wheel_moved(y) = @show.wheel_credits(y)

      def key_pressed(key)
        return @speaker.toggle_mute if key == :m
        return @show.open_credits if key == :c && @show.records?
        return if @show.credits_key(key)
        # Enter or Space presses the screen's main button, on any device;
        # Alt+Enter (Cmd+Enter on a Mac) is fullscreen's instead.
        return @show.primary if PRIMARY_KEYS.include?(key) && !(key != :space && fullscreen_chord?)
        # Escape, which Android's Back arrives as, goes back from the
        # Records screen or Game Over first, on any device.
        return if key == :escape && @show.back
        # On the title Android's Back leaves the app, as Back on an app's
        # first screen does; in a round it does nothing, so a stray edge
        # swipe never throws a round away.
        return ::Lota::Event.quit if key == :escape && @android && @show.title?
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
      def resize
        return unless @show

        happened("a resize")
        report_screen
        @pen.refresh
        @sparks.refresh
        @bloom.refresh
        @game.screen = screen
        @show.resize(layout, @game.field)
        # The heap keeps the finished round's dots, and their radius.
        round = @game.round
        @pile.refit(round ? Field.new(screen.width, screen.height, round.field.radius) : @game.field)
        @renderer.prepare
        @cursor = @cursor.refit(@show.layout.whole)
      end

      private

      # The gamepad's left stick and d-pad for the cursor, which on the
      # Credits screen scroll it instead and leave the cursor at rest.
      def read_with_stick(seconds)
        stick = @gamepads.stick
        return stick unless @show.credits?

        @show.stick_credits(stick, seconds)
        Presentation::Stick.rest
      end

      # Held arrow and Page keys go on scrolling the Credits screen, which
      # is the only place the keyboard asks for repeats.
      def repeat_keys
        reading = @show.credits?
        return if reading == @reading

        @reading = reading
        ::Lota::Keyboard.key_repeat = reading
      end

      # A press at +x+, +y+, by +by+ (a finger's id, :mouse, :gamepad, or
      # the autopilot), which its release names too.
      def tap(x, y, by = :autopilot) = @show.tap(x, y, by:)

      # Tells the Show what made +tap+, if anything did, so its words name
      # that press. Returns +tap+.
      def heard(tap)
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
        return unless @fake_drag && @show.finished?

        width, height = ::Lota::Graphics.dimensions
        @fake_drag.step(@show.finale.at, @show.now, width, height) do |action, x, y|
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

      def open_window
        size = window_size || Look::WINDOW.size_for(*::Lota::Window.desktop_dimensions, @dot_size.radius)
        ::Lota::Window.set_mode(*size, resizable: true, centered: true, minwidth: SMALLEST_WINDOW[0],
                                       minheight: SMALLEST_WINDOW[1])
      end

      # A phone or tablet's window already covers the screen; fullscreen
      # hides the status bar over it and, on iOS, makes a swipe from an
      # edge ask twice before it leaves the game (SDL's UIKit view
      # controller), so a tap near the edge stays a tap.
      def fill_screen = ::Lota::Window.set_fullscreen(true, :desktop)

      # Whether Alt or Cmd is held, which makes Enter switch fullscreen.
      def fullscreen_chord? = ::Lota::Keyboard.down?(:lalt, :ralt, :lgui, :rgui)

      def toggle_fullscreen
        fullscreen, = ::Lota::Window.fullscreen
        happened("a fullscreen switch")
        ::Lota::Window.set_fullscreen(!fullscreen, :desktop)
      end

      # The window as a field of dots at the usual size; the game sizes a
      # round's dots on it as the player chose (DotSizing).
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
        Presentation::Layout.new(width:, height:, safe:, look: Look::LAYOUT)
      end

      # DOT_POPPER_WINDOW=400x850: a window of that size, for checking a
      # narrow screen; nil without it.
      def window_size
        width, height = @env.fetch("DOT_POPPER_WINDOW", "").split("x", 2).map { Integer(it, exception: false) }
        [[width, SMALLEST_WINDOW[0]].max, [height, SMALLEST_WINDOW[1]].max] if width && height
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
      # gamepad's right stick. Every device it runs on has a pointer to
      # drag the dots with, a mouse or a touchscreen, for the hint.
      def tilting(os)
        fake = Presentation::Reading.parse(@env["DOT_POPPER_FAKE_TILT"])
        width, height = ::Lota::Graphics.dimensions
        Tilting.new(pile: @pile, gamepads: @gamepads,
                    accelerometer: fake ? FakeAccelerometer.new(steady: fake) : Accelerometer.new,
                    look: flag?("DOT_POPPER_CALM") ? Look::CALM_TILT : Look::TILT,
                    hint: Presentation::TiltHint.new(SaveFile.new(name: "tilt_hint.txt"), Look::TILT),
                    device: Presentation::TiltHint.device(os, width, height), turns: @touch, pointer: true)
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
      # seconds, from each frame's real time.
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
        if @show.records? then "Your records"
        elsif @show.playing? then "a round"
        elsif @show.finished? then "Game Over"
        else "the title"
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
