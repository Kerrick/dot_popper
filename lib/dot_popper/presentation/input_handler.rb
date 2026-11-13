# frozen_string_literal: true

module DotPopper
  module Presentation
    # Where the shell hands each of the player's inputs, as the game's own
    # events (input_events.rb), and what each does on the screen on top.
    # It keeps what the inputs leave behind them: the gamepad's cursor, A
    # and the right trigger held, the triggers' pulls, the mouse's travel
    # and its switch's chatter. What only the engine can do it asks of
    # +shell+:
    #
    # [splash?], [skip_splash] whether setdef's splash shows, and ending it
    # [quit] closing the game
    # [toggle_fullscreen] a computer's window in or out of fullscreen
    #
    # and Game Over's pile, which presses away from its buttons go to, of
    # +pile+ (Shell::Dragging): +press+, +move+, +release+ and +drop+, by a
    # pointer's key.
    #
    # +platform+ (Platform) says what the system allows: a phone's or
    # tablet's keyboard neither quits nor leaves fullscreen, and an iOS
    # app never quits itself. +cursor+ is the gamepad's (GamepadCursor) as
    # the game starts.
    class InputHandler
      # For a moment after the window opens or changes size, the pointer
      # seems to move under a still mouse, as the window moves under it
      # (Windows sends several such motions as it grows a window to the
      # display's scale), so no motion then takes the words to the mouse.
      SETTLE = 0.5

      PRIMARY_KEYS = %i[enter space].freeze

      # The gamepad's cursor, which the renderer draws.
      attr_reader :cursor

      def initialize(show:, platform:, shell:, pile:, cursor:, style: Style)
        @show = show
        @platform = platform
        @shell = shell
        @pile = pile
        @cursor = cursor
        @style = style
        @router = InputRouter.new
        @buttons = GamepadButtons.new
        @trigger = Trigger.released
        @left_trigger = Trigger.released
        @pad_held = []
        @chatter = Chatter.quiet(style::CHATTER)
        @travel = nil
        @uptime = 0.0
        @settled_at = SETTLE
      end

      # One of the player's inputs (input_events.rb), or nil for something
      # the engine reported that the game has no name for.
      def call(event)
        case event
        in KeyPress then key(event)
        in ButtonPress then button_pressed(event.button)
        in ButtonRelease then button_released(event.button)
        in TriggerPull then trigger_pulled(event)
        in GamepadRemoved then gamepad_removed
        in MousePress then mouse_pressed(event)
        in MouseMove then mouse_moved(event)
        in MouseRelease then mouse_released(event)
        in TouchPress then touch_pressed(event)
        in TouchMove then touch_moved(event)
        in TouchRelease then touch_released(event)
        in WheelTurn then @show.wheel_scroll(event.notches)
        in FocusLost then focus_lost
        in MouseLeft then @show.pointer_gone
        in nil then nil
        end
      end

      # A frame: +elapsed+ seconds of real time since the last, +seconds+
      # of it for the game (Rules::LONGEST_FRAME at most). The gamepad's
      # left stick and d-pad, +stick+, move its cursor, or on the Credits
      # screen scroll it (Show#stick_scrolls?), and +right_stick+ scrolls a
      # list.
      def update(elapsed, seconds, stick:, right_stick:)
        @uptime += elapsed
        moved = @cursor.update(seconds, read_with_stick(seconds, stick, right_stick))
        @show.input = InputKind::GAMEPAD unless moved == @cursor
        @cursor = moved
      end

      # While A or the right trigger is held, the pile's pointer follows
      # the cursor.
      def follow_cursor = (@pile.move(:gamepad, @cursor.x, @cursor.y) if @pad_held.any?)

      # The window changed size: the cursor stays in it, and motions settle
      # (SETTLE).
      def resized(area)
        @settled_at = @uptime + SETTLE
        @cursor = @cursor.refit(area)
      end

      # The fake drag's press, move or release (+action+), made with the
      # gamepad at +x+, +y+ (Shell::DevelopmentHooks#drag): the cursor goes
      # there, and A holds the dot.
      def fake_pad(action, x, y)
        @cursor = @cursor.at(x, y).show
        case action
        in :press then gamepad_down(:a)
        in :release then gamepad_up(:a)
        in :move then nil
        end
      end

      private

      # A key, in order; the first that applies wins.
      def key(press)
        return @shell.skip_splash if @shell.splash?

        @show.keyboard_used(@platform.command_key? ? "⌘B" : "Ctrl+B") unless @platform.touch?
        key = press.key or return
        return if key == :v && press.held?(:ctrl, :command) && @show.paste_shortcut
        # Ctrl+B or Cmd+B buys on the offer: a chord, so no press that means
        # continue or back, and no letter of a typed license key, buys.
        return if key == :b && press.held?(:ctrl, :command) && @show.buy_shortcut
        return if @show.type_key(key)
        return @show.sounds.toggle_mute if key == :m
        return if @show.scroll_key(key)
        # Enter or Space presses the screen's main button, on any device;
        # Alt+Enter (Cmd+Enter on a Mac) is fullscreen's instead.
        return @show.primary if PRIMARY_KEYS.include?(key) && !(key != :space && press.held?(:alt, :command))
        # Escape, which Android's Back arrives as, goes back from the
        # Stats screen or Game Over first, on any device.
        return if key == :escape && @show.back
        # On Home Android's Back leaves the app, as Back on an app's
        # first screen does; in a game it does nothing, so a stray edge
        # swipe never throws a game away. iOS apps never quit themselves.
        return @shell.quit if key == :escape && @platform.quits_itself? && @show.home?
        # A tablet's keyboard neither quits the app nor takes it out of
        # fullscreen: iOS apps are left by the system, never by the app.
        return if @platform.touch?

        case key
        when :escape then @shell.quit
        when :f11 then @shell.toggle_fullscreen
        when :enter then @shell.toggle_fullscreen if press.held?(:alt, :command)
        end
      end

      # A gamepad button went down. Any button shows the cursor;
      # GamepadButtons says what each one asks for.
      def button_pressed(button)
        return @shell.skip_splash if @shell.splash?

        gamepad_used
        case @buttons.intent(button)
        in :press then gamepad_down(:a)
        in :start then @show.start
        in :leave then @show.back || leave_home
        in :x | :y | :lb | :rb | :select => name then @show.pad(name)
        in nil then nil
        end
      end

      # A gamepad button came up. Letting go of A ends its press, which on
      # Game Over throws a dragged dot, or goes on, as a click does; letting
      # go of Y ends a hold of "Clear my stats…".
      def button_released(button)
        case @buttons.intent(button)
        in :press then gamepad_up(:a)
        in :y then @show.let_go(:y)
        in :start then @show.let_go(:start)
        else nil
        end
      end

      # The right trigger presses and lets go as A does; the left, as a
      # button, opens Friend groups on Home (LT).
      def trigger_pulled(pull)
        return left_trigger(pull.value) if pull.trigger == :left
        return @shell.skip_splash if @shell.splash? && pull.value > 0.5

        was_held = @trigger.held
        @trigger = @trigger.pull(pull.value, @style::GAMEPAD)
        return gamepad_up(:trigger) if was_held && !@trigger.held
        return unless @trigger.pressed

        gamepad_used
        gamepad_down(:trigger)
      end

      def left_trigger(value)
        @left_trigger = @left_trigger.pull(value, @style::GAMEPAD)
        return unless @left_trigger.pressed

        gamepad_used
        @show.pad(:lt)
      end

      # A controller was unplugged: its trigger and A are let go.
      def gamepad_removed
        @trigger = Trigger.released
        @pad_held.dup.each { gamepad_up(it) }
      end

      def mouse_pressed(event)
        return if chattered?(event)
        return @shell.skip_splash if @shell.splash?

        @cursor = @cursor.hide(event.x, event.y)
        tap = heard(@router.tap(event))
        @show.pointer_at(tap.x, tap.y) if tap
        press(:mouse, tap)
      end

      # A motion counts as using the mouse only once it has gone far
      # enough (MouseTravel); a drag follows it either way, and so does
      # what the mouse is over, for its hover.
      def mouse_moved(event)
        point = @router.tap(event) or return
        @show.pointer_at(point.x, point.y)
        @travel = nil if window_settling?
        @travel = (@travel || MouseTravel.start).moved(event.x, event.y)
        if @travel.deliberate?
          @cursor = @cursor.hide(event.x, event.y)
          heard(point)
        end
        @show.drag_scroll(:mouse, point.y)
        @pile.move(:mouse, point.x, point.y)
      end

      def mouse_released(event)
        return if released_chatter?(event)

        point = @router.tap(event) or return
        @show.let_go(:mouse)
        @pile.release(:mouse, point.x, point.y)
      end

      def touch_pressed(event)
        return @shell.skip_splash if @shell.splash?

        @cursor = @cursor.hide
        press(event.id, heard(@router.tap(event)))
      end

      def touch_moved(event)
        point = heard(@router.tap(event))
        return unless point

        @show.drag_scroll(event.id, point.y)
        @pile.move(event.id, point.x, point.y)
      end

      def touch_released(event)
        point = @router.tap(event) or return
        @show.let_go(event.id)
        @pile.release(event.id, point.x, point.y)
      end

      # The window lost focus. A finger or button let go meanwhile is never
      # heard, so the pile's dots are let go now, and so is "Clear my
      # stats…", and no release is waited for to drop.
      def focus_lost
        @pile.drop
        @chatter = @chatter.let_go
        @show.let_go_of_everything
        @show.pointer_gone
      end

      def window_settling? = @uptime < @settled_at

      # The gamepad's left stick and d-pad for the cursor, which on the
      # Credits screen scroll it instead and leave the cursor at rest
      # (Show#stick_scrolls?).
      def read_with_stick(seconds, stick, right_stick)
        @show.stick_scroll(right_stick, seconds)
        return stick unless @show.stick_scrolls?

        @show.stick_scroll(stick, seconds)
        Stick.rest
      end

      # Whether a mouse press is its switch chattering (Chatter), to be
      # dropped, wherever it lands, as its release will be. Its clock is
      # the frames' time, unclamped: the real time in play, and the
      # scenario's in the GUI suite.
      def chattered?(event)
        return false if event.made_up

        @chatter, chatter = @chatter.press(event.button, event.x.to_f, event.y.to_f, at: @uptime)
        chatter
      end

      def released_chatter?(event)
        return false if event.made_up

        @chatter, chatter = @chatter.release(event.button)
        chatter
      end

      # Tells the Show what made +tap+, if anything did, so its words name
      # that press. Returns +tap+. A finger starts the mouse's travel
      # afresh, as the gamepad does, so only a new, deliberate move takes
      # the words back to the mouse.
      def heard(tap)
        @travel = nil if tap && tap.kind != InputKind::MOUSE
        @show.input = tap.kind if tap
        tap
      end

      # The gamepad was used: its cursor shows, and the words name its
      # buttons.
      def gamepad_used
        @travel = MouseTravel.start
        @cursor = @cursor.show
        @show.input = InputKind::GAMEPAD
      end

      # A mouse button or finger went down, as +tap+ (or nil for none), by
      # +key+ (a finger's id, :mouse, or :gamepad), which its release
      # names too. It counts at once, unless the Show waits for its
      # release, on Game Over, where it may become a drag.
      def press(key, tap)
        return unless tap
        return @show.tap(tap.x, tap.y, by: key) unless @show.waits_for_release?(tap.x, tap.y)

        @pile.press(key, tap.x, tap.y)
      end

      # A or the right trigger, +source+, went down: a press at the cursor,
      # as a mouse button's. On Game Over it waits to be let go, as a
      # click does, and held on a dot it drags it; elsewhere it counts at
      # once. A second source held with the first adds nothing.
      def gamepad_down(source)
        @pad_held << source
        press(:gamepad, @router.gamepad_pressed(@cursor)) if @pad_held.size == 1
      end

      # A or the right trigger let go: once neither is held, the press ends
      # where the cursor is.
      def gamepad_up(source)
        return unless @pad_held.delete(source) && @pad_held.empty?

        point = @router.gamepad_released(@cursor)
        @show.let_go(:gamepad)
        @pile.release(:gamepad, point.x, point.y)
      end

      # B on Home: asks, then quits on a second press, as Escape quits
      # from the keyboard. iOS apps are left by the system, never by the app.
      def leave_home
        @shell.quit if @platform.quits_itself? && @show.ask_to_quit == :quit
      end
    end
  end
end
