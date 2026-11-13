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

      # What the GUI suite's director (test/gui/director.rb) watches as it
      # plays: the rules, the Show, and the game-over pile.
      attr_reader :cabinet, :show, :pile

      # +channel+ is the build's (Build::CHANNEL). It, and not the
      # environment, decides which keys and store this run trusts, and
      # which developer settings it obeys (Composition::Settings).
      def initialize(env = ENV, channel: Build::CHANNEL)
        @settings = Composition::Settings.new(env, channel:)
        Automation.guard!(exit_on_attempt: true) if @settings.automated?
        @uptime = 0.0
        @chatter = Presentation::Chatter.quiet(Style::CHATTER)
        @clock = Presentation::FrameClock.start
      end

      # Builds the game (Composition::Root) on what Lota gives it, then
      # what carries the game out with Lota: the pile, gamepads, tilting,
      # dragging, particles and the renderer.
      def load
        @engine = Engine.new(Platforms.for(::Lota::System.os))
        @game = Composition::Root.new(engine: @engine, settings: @settings)
        @platform = @game.platform
        @touch = @platform.touch?
        @window = @game.window
        @cabinet = @game.cabinet
        @show = @game.show
        @pen = @game.pen
        @speaker = @game.speaker
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
        @sparks = Sparks.new(Style)
        @bloom = Bloom.new(@pen, Style::BLOOM)
        @renderer = Renderer.new(@show, @pen, pile: @pile, sparks: @sparks, bloom: @bloom,
                                             diagnostic: flag?("DOT_POPPER_DIAGNOSTIC_COLORS"))
        @renderer.prepare
        @input = LotaInput.new
        @buttons = Presentation::GamepadButtons.new
        @trigger = Presentation::Trigger.released
        @cursor = @game.cursor
        @pad_held = []
        @autopilot = @game.autopilot
        @hooks = DevelopmentHooks.for(@settings, cabinet: @cabinet, show: @show, pile: @pile, dragging: @dragging,
                                                 pad: ->(action, x, y) { fake_pad(action, x, y) })
      end

      # Lota's frame, which Lota measured as +measured+ seconds: the game
      # moves on by the time between frames starting to draw (FrameClock).
      def tick(measured)
        @clock, seconds = @clock.tick(::Lota::Timer.time, measured)
        update(seconds)
      end

      def update(seconds)
        @hooks&.frame_started(seconds)
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
        @watch.update # what it found, Continuity::Gone announces
        use_theme
        point_the_mouse
        repeat_keys
        @tilting.update(seconds)
        @hooks&.drag
        @dragging.move(:gamepad, @cursor.x, @cursor.y) if @pad_held.any?
        @dragging.update(seconds)
        @pile.update(seconds)
        @sparks.update(seconds, @show.effects)
        @hooks&.frame_ended(seconds)
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
      # Getting it back is also how a phone's game hears it came back to
      # the foreground (SDL gives the window focus as iOS's scene becomes
      # active and as Android's window gains focus), and Refresh decides
      # whether that asks the server again.
      def focus(focused)
        return @game.refresh.came_back if focused

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
        case @buttons.intent(@input.button(button))
        in :press then gamepad_down(:a)
        in :start then @show.start
        in :y then y_pressed
        in :leave then @show.back || leave_home
        in :x | :lb | :rb | :select => name then @show.pad(name)
        in nil then nil
        end
      end

      # Y: on Home and Settings a button of its own, and Game Over's
      # Share my score.
      def y_pressed
        @show.game_over? || @show.sharing? ? @show.share : @show.pad(:y)
      end

      # A gamepad button came up. Letting go of A ends its press, which on
      # Game Over throws a dragged dot, or goes on, as a click does; letting
      # go of Y ends a hold of "Clear my stats…".
      def gamepad_released(button)
        case @buttons.intent(@input.button(button))
        in :press then gamepad_up(:a)
        in :y then @show.let_go(:y)
        in :start then @show.let_go(:start)
        else nil
        end
      end

      # A gamepad's axis moved. The right trigger presses and lets go as A
      # does; the sticks are read each frame instead (Gamepads).
      def gamepad_axis(axis, value)
        trigger = @input.trigger(axis)
        return left_trigger(value) if trigger == :left
        return unless trigger == :right
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

        @show.keyboard_used(@platform.command_key? ? "\u2318B" : "Ctrl+B") unless @touch
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
        # On Home Android's Back leaves the app, as Back on an app's
        # first screen does; in a game it does nothing, so a stray edge
        # swipe never throws a game away. iOS apps never quit themselves.
        return ::Lota::Event.quit if key == :escape && @platform.quits_itself? && @show.home?
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

        @hooks&.happened("a resize")
        @engine.report_screen
        @pen.refresh
        @sparks.refresh
        @bloom.refresh
        @cabinet.screen = screen
        @show.resize(@engine.layout, @cabinet.field)
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

      # A mouse button or finger went down, as +tap+ (or nil for none). It
      # counts at once, unless the Show waits for its release, on Game
      # Over, where it may become a drag.
      def press(key, tap)
        return unless tap
        return tap(tap.x, tap.y, key) unless @show.waits_for_release?(tap.x, tap.y)

        @dragging.press(key, tap.x, tap.y)
      end

      # The fake drag's press, move or release, made with the gamepad
      # (DevelopmentHooks#drag): the cursor goes there, and A holds the dot.
      def fake_pad(action, x, y)
        @cursor = @cursor.at(x, y).show
        case action
        in :press then gamepad_down(:a)
        in :release then gamepad_up(:a)
        in :move then nil
        end
      end

      def fake_gamepad? = @settings.fake_gamepad?

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

      # B on Home: asks, then quits on a second press, as Escape quits
      # from the keyboard. iOS apps are left by the system, never by the app.
      def leave_home
        ::Lota::Event.quit if @platform.quits_itself? && @show.ask_to_quit == :quit
      end

      # Whether Ctrl or Cmd is held, which makes V paste.
      def paste_chord? = ::Lota::Keyboard.down?(:lctrl, :rctrl, :lgui, :rgui)

      # Whether Alt or Cmd is held, which makes Enter switch fullscreen.
      def fullscreen_chord? = ::Lota::Keyboard.down?(:lalt, :ralt, :lgui, :rgui)

      # F11 or Alt+Enter, as Home's "Full screen" (DesktopWindow).
      def toggle_fullscreen
        @hooks&.happened("a fullscreen switch")
        @window.toggle_fullscreen
      end

      def screen = @game.screen

      def flag?(name) = @settings.flag?(name)
    end
  end
end
