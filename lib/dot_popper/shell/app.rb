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

      # What the GUI suite's scenario runner (test/gui/scenario_runner.rb) watches as it
      # plays: the rules, the Show, and the game-over pile.
      attr_reader :cabinet, :show, :pile

      # +channel+ is the build's (Build::CHANNEL). It, and not the
      # environment, decides which keys and store this run trusts, and
      # which developer settings it obeys (Composition::DeveloperSettings).
      def initialize(env = ENV, channel: Build::CHANNEL)
        @settings = Composition::DeveloperSettings.new(env, channel:)
        Automation.guard!(exit_on_attempt: true) if @settings.automated?
        @clock = Presentation::FrameClock.start
      end

      # Builds the game (Composition::Root) on what Lota gives it, then
      # what carries the game out with Lota: the pile, gamepads, tilting,
      # dragging, particles and the renderer.
      def load
        @engine = Engine.new(::Lota::System.os)
        @game = Composition::Root.new(engine: @engine, settings: @settings)
        @platform = @game.platform
        @touch = @platform.touch?
        @window = @game.window
        @cabinet = @game.cabinet
        @show = @game.show
        @pen = @game.pen
        @sound_player = @game.sound_player
        @splash = @game.splash
        @theme_feed = @game.theme_feed
        @watch = @game.watch
        @game.start
        @pile = Pile.new(@game.pile_style)
        @cabinet.subscribe(@pile)
        @gamepads = Gamepads.new(pretend: fake_gamepad?)
        fake = @game.fake_tilt
        @tilting = Tilting.new(pile: @pile, gamepads: @gamepads,
                               accelerometer: fake ? FakeAccelerometer.new(steady: fake) : Accelerometer.new,
                               style: @game.tilt_style, turns: @touch)
        @cabinet.subscribe(@tilting)
        @dragging = Dragging.new(pile: @pile, show: @show, style: @game.grab_style)
        @cabinet.subscribe(@dragging)
        @particle_systems = ParticleSystems.new(Style)
        @bloom = Bloom.new(@pen, Style::BLOOM)
        @renderer = Renderer.new(@show, @pen, pile: @pile, particle_systems: @particle_systems, bloom: @bloom,
                                             diagnostic: flag?("DOT_POPPER_DIAGNOSTIC_COLORS"))
        @renderer.prepare
        @input = LotaInput.new
        @inputs = Presentation::InputHandler.new(show: @show, platform: @platform, shell: self, pile: @dragging, cursor: @game.cursor)
        @bot = @game.bot
        @hooks = DevelopmentHooks.for(@settings, cabinet: @cabinet, show: @show, pile: @pile, dragging: @dragging,
                                                 pad: ->(action, x, y) { @inputs.fake_pad(action, x, y) })
      end

      # Lota's frame, which Lota measured as +measured+ seconds: the game
      # moves on by the time between frames starting to draw (FrameClock).
      def tick(measured)
        @clock, seconds = @clock.tick(::Lota::Timer.time, measured)
        update(seconds)
      end

      def update(seconds)
        @hooks&.frame_started(seconds)
        elapsed = seconds
        seconds = seconds.clamp(0.0, Rules::LONGEST_FRAME)
        if @splash
          @splash.notes(seconds).each { @sound_player.play(:tick, pitch: it.pitch) }
          @splash = @splash.advance(seconds)
        end
        @splash = nil if @splash&.over?
        @inputs.update(elapsed, seconds, stick: @gamepads.stick, right_stick: @gamepads.right_stick)
        if @bot
          x, y = @bot.update(seconds, @cabinet, @show)
          tap(x, y) if x
        end
        @cabinet.update(seconds)
        @show.update(seconds)
        @theme_feed&.update
        @watch.update # what it found, Continuity::Gone announces
        use_theme
        point_the_mouse
        repeat_keys
        @tilting.update(seconds)
        @hooks&.drag
        @inputs.follow_cursor
        @dragging.update(seconds)
        @pile.update(seconds)
        @particle_systems.update(seconds, @show.effects)
        @hooks&.frame_ended(seconds)
      end

      def draw
        @clock = @clock.drawing(::Lota::Timer.time)
        @renderer.draw(@inputs.cursor, @splash)
      end

      # Each of Lota's input callbacks, as the game's own event
      # (LotaInput), for the Presentation::InputHandler, which decides
      # what it means.
      def mouse_pressed(x, y, button, istouch) = @inputs.call(@input.mouse_press(x, y, button, istouch))
      def mouse_moved(x, y, istouch) = @inputs.call(@input.mouse_move(x, y, istouch))
      def mouse_released(x, y, button, istouch) = @inputs.call(@input.mouse_release(x, y, button, istouch))
      def touch_pressed(id, x, y, devicetype, mouse) = @inputs.call(@input.touch_press(id, x, y, devicetype, mouse))
      def touch_moved(id, x, y, devicetype, mouse) = @inputs.call(@input.touch_move(id, x, y, devicetype, mouse))
      def touch_released(id, x, y, devicetype, mouse) = @inputs.call(@input.touch_release(id, x, y, devicetype, mouse))
      def gamepad_pressed(button) = @inputs.call(@input.button_press(button))
      def gamepad_released(button) = @inputs.call(@input.button_release(button))
      def gamepad_axis(axis, value) = @inputs.call(@input.trigger_pull(axis, value))
      def wheel_moved(y) = @inputs.call(@input.wheel_turn(y))

      # The window lost focus or got it back. A finger or button let go
      # meanwhile is never heard, so the pile's dots are let go now, and
      # so is "Clear my stats…", and no release is waited for to drop.
      # Getting it back is also how a phone's game hears it came back to
      # the foreground (SDL gives the window focus as iOS's scene becomes
      # active and as Android's window gains focus), and Refresh decides
      # whether that asks the server again.
      def focus(focused)
        return @game.refresh.came_back if focused

        @inputs.call(Presentation::FocusLost.new)
      end

      # The mouse left the window, or came back into it. Once it has
      # left, it is over no button; back in, its next motion says where.
      def mouse_focus(focused)
        @inputs.call(Presentation::MouseLeft.new) unless focused
      end

      # What the Presentation::InputHandler asks of the engine: whether
      # setdef's splash shows, and ending it, which the game never hears;
      # closing the game; and switching fullscreen, as F11 does
      # (DesktopWindow).
      def splash? = !@splash.nil?
      def skip_splash = @splash = @splash.skip
      def quit = ::Lota::Event.quit

      def toggle_fullscreen
        @hooks&.happened("a fullscreen switch")
        @window.toggle_fullscreen
      end

      # Whether the mouse pointer is the system's pointing hand, as it is
      # while the mouse is over a button.
      def pointing_hand? = @hand == true

      # A controller was plugged in, or was there when the game started.
      def gamepad_added(joystick) = @gamepads.added(joystick)

      # A controller was unplugged: forget it, and let its trigger go.
      def gamepad_removed(joystick)
        @gamepads.removed(joystick)
        @inputs.call(Presentation::GamepadRemoved.new)
      end

      # A key went down, which Lota calls +name+: the game's name for it
      # and the modifier keys held, for the Presentation::InputHandler.
      def key_pressed(name) = @inputs.call(@input.key_press(name, ::Lota::Keyboard.method(:down?)))

      # The window changed size, or moved to a screen of another density.
      def resize
        return unless @show

        @hooks&.happened("a resize")
        @engine.report_screen
        @pen.refresh
        @particle_systems.refresh
        @bloom.refresh
        @cabinet.screen = screen
        @show.resize(@engine.layout, @cabinet.field)
        # The heap keeps the finished game's dots, and their radius.
        game = @cabinet.game
        @pile.refit(game ? Field.new(screen.width, screen.height, game.field.radius) : @cabinet.field)
        @renderer.prepare
        @inputs.resized(@show.layout.whole)
      end

      private

      # Held arrow and Page keys go on scrolling the lists, and the only
      # places the keyboard asks for repeats.
      def repeat_keys
        reading = @show.scrolling?
        return if reading == @reading

        @reading = reading
        ::Lota::Keyboard.key_repeat = reading
      end

      # Puts on the Show's look if it has changed (Presentation::ThemeKeeper),
      # which is only ever between games.
      def use_theme
        return unless @pen.use(@show.in_use)

        @renderer.prepare
        @sound_player.use(@show.in_use)
      end

      # The bot's press at +x+, +y+.
      def tap(x, y) = @show.tap(x, y, by: :bot)

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

      def fake_gamepad? = @settings.fake_gamepad?

      def screen = @game.screen

      def flag?(name) = @settings.flag?(name)
    end
  end
end
