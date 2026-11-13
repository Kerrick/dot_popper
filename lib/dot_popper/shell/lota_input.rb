# frozen_string_literal: true

module DotPopper
  module Shell
    # Lota's input callbacks as the game's own events
    # (Presentation::KeyPress, MousePress and the rest), for the
    # Presentation::InputHandler, which decides what each means. A gamepad's
    # buttons and triggers, the keys and the mouse's buttons come by LÖVE's
    # names (an Xbox pad's for every gamepad, as SDL maps them), and leave
    # here by the game's; nothing else is decided here.
    class LotaInput
      E = Presentation

      # LÖVE's names for the buttons the game names. The rest (the d-pad,
      # the sticks' clicks, the guide button) name nothing.
      BUTTONS = { a: :a, b: :b, x: :x, y: :y, start: :start, back: :select, leftshoulder: :lb, rightshoulder: :rb }.freeze
      # LÖVE's names for the trigger axes.
      TRIGGERS = { "triggerleft" => :left, "triggerright" => :right }.freeze
      # LÖVE's numbers for the mouse's main buttons. A side button is
      # :side4 and up.
      MOUSE_BUTTONS = { 1 => :left, 2 => :right, 3 => :middle }.freeze

      # LÖVE's names for the keys the game names, the keypad's as the
      # main keys': the letters and digits, and the keys that edit, move,
      # confirm and leave. The rest (Shift, Tab, the other function keys)
      # name nothing.
      KEYS = {
        **[*("a".."z"), *("0".."9")].to_h { [it, it.to_sym] }, **("0".."9").to_h { ["kp#{it}", it.to_sym] },
        "minus" => :minus, "kpminus" => :minus, "backspace" => :backspace, "delete" => :delete,
        "return" => :enter, "kpenter" => :enter, "space" => :space, "escape" => :escape, "f11" => :f11,
        "up" => :up, "down" => :down, "pageup" => :page_up, "pagedown" => :page_down, "home" => :home, "end" => :end
      }.freeze

      # LÖVE's names for the modifier keys, by the game's: Ctrl, Alt, and
      # Cmd on a Mac (the Windows or Super key elsewhere), either side.
      MODIFIERS = { ctrl: %i[lctrl rctrl], alt: %i[lalt ralt], command: %i[lgui rgui] }.freeze

      # A mouse button, by LÖVE's number, went down or came up, or the
      # mouse moved; +istouch+ is true where SDL made it up for a finger.
      def mouse_press(x, y, button, istouch) = E::MousePress.new(x:, y:, button: mouse_button(button), made_up: istouch ? true : false)
      def mouse_release(x, y, button, istouch) = E::MouseRelease.new(x:, y:, button: mouse_button(button), made_up: istouch ? true : false)
      def mouse_move(x, y, istouch) = E::MouseMove.new(x:, y:, made_up: istouch ? true : false)

      # A touch +id+ went down, moved, or lifted, on a device of
      # +devicetype+ (a touchscreen's, or a trackpad's); +mouse+ is true
      # where SDL made it up from the mouse.
      def touch_press(id, x, y, devicetype, mouse) = E::TouchPress.new(id:, x:, y:, **finger(devicetype, mouse))
      def touch_move(id, x, y, devicetype, mouse) = E::TouchMove.new(id:, x:, y:, **finger(devicetype, mouse))
      def touch_release(id, x, y, devicetype, mouse) = E::TouchRelease.new(id:, x:, y:, **finger(devicetype, mouse))

      # The gamepad button LÖVE calls +name+ went down or came up.
      def button_press(name) = E::ButtonPress.new(button: button(name))
      def button_release(name) = E::ButtonRelease.new(button: button(name))

      # The axis LÖVE calls +axis+ read +value+: a trigger's pull, or nil
      # for a stick's axis, which is read each frame instead (Gamepads).
      def trigger_pull(axis, value) = trigger(axis)&.then { E::TriggerPull.new(trigger: it, value: value.to_f) }

      # The mouse wheel turned +y+ notches, up when positive.
      def wheel_turn(y) = E::WheelTurn.new(notches: y)

      # The key LÖVE calls +name+ pressed, with the modifier keys that
      # +down+ (Lota::Keyboard.down?, given LÖVE's names) says are held.
      def key_press(name, down) = E::KeyPress.new(key: key(name), held: MODIFIERS.filter_map { |modifier, keys| modifier if down.call(*keys) })

      # The game's name for the gamepad button LÖVE calls +name+, or nil.
      def button(name) = BUTTONS[name.to_s.to_sym]

      # :left or :right for the trigger axis LÖVE calls +axis+, or nil for
      # another axis.
      def trigger(axis) = TRIGGERS[axis.to_s]

      # The game's name for the key LÖVE calls +name+, or nil.
      def key(name) = KEYS[name.to_s]

      # The game's name for the mouse button LÖVE numbers +number+.
      def mouse_button(number) = MOUSE_BUTTONS.fetch(number) { :"side#{number}" }

      private

      def finger(devicetype, mouse) = { screen: devicetype.to_s == "touchscreen", made_up: mouse == true }
    end
  end
end
