# frozen_string_literal: true

module DotPopper
  module Shell
    # The game running in Lota's window. main.rb hands each of Lota's
    # callbacks to one of these methods. Each frame, taps go to the game
    # first, on the frame they happen; then the gamepad cursor moves and
    # the rules move on; then the Show catches up; then the Renderer
    # draws it.
    class App
      Look = Presentation::Look
      PLAYTEST_LOG = "rounds.csv"
      SMALLEST_WINDOW = [400, 320].freeze

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
        random = seed ? Random.new(seed) : Random.new
        # Bests saved before they were kept by size of screen go to this
        # screen's class.
        legacy = SizeClass.of(screen)
        sizing_store = SaveFile.new(name: "dot_size.txt")
        @game = Game.new(screen, best: BestScore.new(SaveFile.new(name: "best_score.txt"), legacy:), random:,
                                 sizing: DotSizing.parse(sizing_store.read))
        puts "Dot Popper: dots are sized to the screen as each round starts" if @game.sizing.sized_to_screen?
        @speaker = Speaker.new(Look::PATCHES, store: SaveFile.new(name: "sound.txt"), volume: Look::SOUND.volume)
        @show = Presentation::Show.new(game: @game, layout:, sounds: @speaker, radius: @dot_size.radius,
                                       random:, calm: flag?("DOT_POPPER_CALM"),
                                       tutor: Presentation::Tutor.new(SaveFile.new(name: "taught.txt"),
                                                                    times: Look::LESSON.times),
                                       haptics: Haptics.for(os), clipboard: Clipboard.new,
                                       lifetime: Lifetime.new(SaveFile.new(name: "lifetime.txt"), today:, legacy:),
                                       sizing_store:)
        @game.subscribe(PlaytestLog.new(SaveFile.new(name: PLAYTEST_LOG), today:,
                                        archive: ->(name) { SaveFile.new(name:) }))
        puts "Dot Popper: each round is logged in #{File.join(::Lota::Filesystem.save_directory, PLAYTEST_LOG)}"
        @pile = Pile.new(flag?("DOT_POPPER_CALM") ? Look::CALM_PILE : Look::PILE)
        @game.subscribe(@pile)
        @gamepads = Gamepads.new
        @tilting = tilting(os)
        @game.subscribe(@tilting)
        @dragging = Dragging.new(pile: @pile, show: @show, look: flag?("DOT_POPPER_CALM") ? Look::CALM_GRAB : Look::GRAB)
        @game.subscribe(@dragging)
        @fake_drag = Presentation::FakeDrag.parse(@env["DOT_POPPER_FAKE_DRAG"])
        @pen = Pen.new(Look, shaders: !flag?("DOT_POPPER_NO_SHADERS"))
        @sparks = Sparks.new(Look)
        @bloom = Bloom.new(@pen, Look::BLOOM)
        @renderer = Renderer.new(@show, @pen, pile: @pile, sparks: @sparks, bloom: @bloom, tilting: @tilting)
        @renderer.prepare
        @input = Presentation::InputRouter.new
        @buttons = Presentation::GamepadButtons.new
        @trigger = Presentation::Trigger.released
        @cursor = Presentation::GamepadCursor.centered(@show.layout.whole, look: Look::GAMEPAD,
                                                       radius: @dot_size.radius)
        @autopilot = Presentation::Autopilot.new(Look::AUTOPILOT) if flag?("DOT_POPPER_AUTOPLAY")
        @shots = Presentation::ShotSchedule.parse(@env["DOT_POPPER_SHOTS"])
        @quit_after = Float(@env.fetch("DOT_POPPER_QUIT_AFTER", ""), exception: false)
        @frames = Presentation::FrameMeter.start(5) if flag?("DOT_POPPER_PERF")
      end

      def update(seconds)
        measure(seconds)
        seconds = seconds.clamp(0.0, Rules::LONGEST_FRAME)
        @cursor = @cursor.update(seconds, @gamepads.stick)
        if @autopilot
          x, y = @autopilot.update(seconds, @game, @show)
          tap(x, y) if x
        end
        @game.update(seconds)
        @show.update(seconds)
        @tilting.update(seconds)
        fake_drag
        @dragging.update(seconds)
        @pile.update(seconds)
        @sparks.update(seconds, @show.effects)
        development(seconds)
      end

      def draw = @renderer.draw(@cursor)

      def mouse_pressed(x, y, button, istouch)
        @cursor = @cursor.hide(x, y)
        press(:mouse, @input.mouse_pressed(x, y, button, istouch))
      end

      def mouse_moved(x, y, istouch)
        @cursor = @cursor.hide(x, y)
        point = @input.mouse_moved(x, y, istouch)
        @dragging.move(:mouse, point.x, point.y) if point
      end

      def mouse_released(x, y, button, istouch)
        point = @input.mouse_released(x, y, button, istouch)
        @dragging.release(:mouse, point.x, point.y) if point
      end

      def touch_pressed(id, x, y, devicetype, mouse)
        @cursor = @cursor.hide
        press(id, @input.touch_pressed(id, x, y, devicetype, mouse))
      end

      def touch_moved(id, x, y, devicetype, mouse)
        point = @input.touch_moved(id, x, y, devicetype, mouse)
        @dragging.move(id, point.x, point.y) if point
      end

      def touch_released(id, x, y, devicetype, mouse)
        point = @input.touch_released(id, x, y, devicetype, mouse)
        @dragging.release(id, point.x, point.y) if point
      end

      # The window lost focus or got it back. A finger or button let go
      # meanwhile is never heard, so the pile's dots are let go now.
      def focus(focused)
        @dragging.drop unless focused
      end

      # A gamepad button went down (Lota 0.1.3 and newer). Any button shows
      # the cursor; GamepadButtons says what each one asks for.
      def gamepad_pressed(button)
        @cursor = @cursor.show
        case @buttons.intent(button)
        in :press then gamepad_tap
        in :start then @show.start
        in :share then @show.share
        in :records then @show.open_records if @show.records_offered?
        in :leave then @show.back
        in :mute then @speaker.toggle_mute
        in :sizing then @show.toggle_sizing
        in nil then nil
        end
      end

      # A gamepad's axis moved. The right trigger presses as A does; the
      # sticks are read each frame instead (Gamepads).
      def gamepad_axis(axis, value)
        return unless axis.to_s == "triggerright"

        @trigger = @trigger.pull(value.to_f, Look::GAMEPAD)
        return unless @trigger.pressed

        @cursor = @cursor.show
        gamepad_tap
      end

      # A controller was plugged in, or was there when the game started.
      def gamepad_added(joystick) = @gamepads.added(joystick)

      # A controller was unplugged: forget it, and let its trigger go.
      def gamepad_removed(joystick)
        @gamepads.removed(joystick)
        @trigger = Presentation::Trigger.released
      end

      def key_pressed(key)
        return @speaker.toggle_mute if key == :m
        # Escape leaves the Records screen first, on any device.
        return if key == :escape && @show.back
        # Android's Back arrives as Escape. On the title it leaves the app,
        # as Back on an app's first screen does; anywhere else it does
        # nothing, so a stray edge swipe never throws a round away.
        return ::Lota::Event.quit if key == :escape && @android && @show.title?
        # A tablet's keyboard neither quits the app nor takes it out of
        # fullscreen: iOS apps are left by the system, never by the app.
        return if @touch

        case key
        when :escape then ::Lota::Event.quit
        when :f11 then toggle_fullscreen
        when :return, :kpenter then toggle_fullscreen if ::Lota::Keyboard.down?(:lalt, :ralt, :lgui, :rgui)
        end
      end

      # The window changed size, or moved to a screen of another density.
      def resize
        return unless @show

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

      def tap(x, y) = @show.tap(x, y)

      # A mouse button or finger went down, as +tap+ (or nil for none). It
      # counts at once, unless the Show waits for its release, on Game
      # Over, where it may become a drag.
      def press(key, tap)
        return unless tap
        return tap(tap.x, tap.y) unless @show.waits_for_release?(tap.x, tap.y)

        @dragging.press(key, tap.x, tap.y)
      end

      # DOT_POPPER_FAKE_DRAG's drag, a step each frame once Game Over has
      # been shown long enough.
      def fake_drag
        return unless @fake_drag && @show.finished?

        width, height = ::Lota::Graphics.dimensions
        @fake_drag.step(@show.finale.at, @show.now, width, height) do |action, x, y|
          x, y = nearest_ball(x, y) if action == :press
          unless action == :move
            puts "Dot Popper: the fake drag #{action == :press ? "takes" : "throws"} a dot at #{x.round}, #{y.round}, " \
                 "#{@elapsed.round(1)} seconds in"
          end
          @dragging.public_send(action, :fake, x, y)
        end
      end

      def gamepad_tap
        tap = @input.gamepad_pressed(@cursor)
        tap(tap.x, tap.y)
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

      def toggle_fullscreen
        fullscreen, = ::Lota::Window.fullscreen
        ::Lota::Window.set_fullscreen(!fullscreen, :desktop)
      end

      # The window as a field of dots at the usual size; the game sizes a
      # round's dots on it as the player chose (DotSizing).
      def screen = @dot_size.field(*::Lota::Graphics.dimensions)

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
      def measure(seconds)
        return unless @frames

        @frames, report = @frames.record(seconds)
        puts "Dot Popper: #{report}" if report
      end

      def screenshot(number)
        name = "shot-#{number}.png"
        ::Lota::Graphics.capture_screenshot(name)
        puts "Dot Popper: screenshot #{File.join(::Lota::Filesystem.save_directory, name)}"
      end
    end
  end
end
