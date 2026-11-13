# frozen_string_literal: true

module DotPopper
  module Shell
    # Lota's input callbacks, in the game's own terms, for
    # Presentation::InputRouter (+router+). A finger on a touchscreen fires
    # touchpressed, and SDL then also makes up a mousepressed for it with
    # +istouch+ true; only the touch counts, so one finger is one tap. A
    # touch whose +devicetype+ isn't a touchscreen (a trackpad's, with 0 to
    # 1 coordinates), or that came from the mouse (+mouse+), is no finger.
    # A gamepad's buttons and triggers come by LÖVE's names for an Xbox
    # pad's (SDL maps every other gamepad to them), and leave here by the
    # game's (Presentation::GamepadButtons); so do the keys.
    class LotaInput < Data.define(:router)
      # LÖVE's names for the buttons the game names. The rest (the d-pad,
      # the sticks' clicks, the guide button) name nothing.
      BUTTONS = { a: :a, b: :b, x: :x, y: :y, start: :start, back: :select, leftshoulder: :lb, rightshoulder: :rb }.freeze
      # LÖVE's names for the trigger axes.
      TRIGGERS = { "triggerleft" => :left, "triggerright" => :right }.freeze
      # LÖVE's numbers for the mouse buttons that count as a press: the
      # left, the right and the middle. A mouse's side buttons do not.
      MOUSE_BUTTONS = [1, 2, 3].freeze

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

      def initialize(router: Presentation::InputRouter.new) = super

      def mouse_pressed(x, y, button, istouch) = (router.mouse_pressed(x, y) if mouse?(button, istouch))
      def mouse_moved(x, y, istouch) = (router.mouse_moved(x, y) unless istouch)
      def mouse_released(x, y, button, istouch) = (router.mouse_released(x, y) if mouse?(button, istouch))

      def touch_pressed(id, x, y, devicetype, mouse) = (router.touch_pressed(id, x, y) if finger?(devicetype, mouse))
      def touch_moved(id, x, y, devicetype, mouse) = (router.touch_moved(id, x, y) if finger?(devicetype, mouse))
      def touch_released(id, x, y, devicetype, mouse) = (router.touch_released(id, x, y) if finger?(devicetype, mouse))

      # The game's name for the gamepad button LÖVE calls +name+, or nil.
      def button(name) = BUTTONS[name.to_s.to_sym]

      # :left or :right for the trigger axis LÖVE calls +axis+, or nil for
      # another axis.
      def trigger(axis) = TRIGGERS[axis.to_s]

      # The game's name for the key LÖVE calls +name+, or nil.
      def key(name) = KEYS[name.to_s]

      # The key LÖVE calls +name+ pressed, with the modifier keys that
      # +down+ (Lota::Keyboard.down?, given LÖVE's names) says are held.
      def key_press(name, down) = Presentation::KeyPress.new(key: key(name), held: MODIFIERS.filter_map { |modifier, keys| modifier if down.call(*keys) })

      def gamepad_pressed(cursor) = router.gamepad_pressed(cursor)
      def gamepad_released(cursor) = router.gamepad_released(cursor)

      private

      def finger?(devicetype, mouse) = devicetype.to_s == "touchscreen" && mouse != true
      def mouse?(button, istouch) = !istouch && MOUSE_BUTTONS.include?(button)
    end
  end
end
