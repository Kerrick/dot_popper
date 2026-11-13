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
    # game's (Presentation::GamepadButtons).
    class LotaInput < Data.define(:router)
      # LÖVE's names for the buttons the game names. The rest (the d-pad,
      # the sticks' clicks, the guide button) name nothing.
      BUTTONS = { a: :a, b: :b, x: :x, y: :y, start: :start, back: :select, leftshoulder: :lb, rightshoulder: :rb }.freeze
      # LÖVE's names for the trigger axes.
      TRIGGERS = { "triggerleft" => :left, "triggerright" => :right }.freeze

      def initialize(router: Presentation::InputRouter.new) = super

      def mouse_pressed(x, y, button, istouch) = (router.mouse_pressed(x, y, button) unless istouch)
      def mouse_moved(x, y, istouch) = (router.mouse_moved(x, y) unless istouch)
      def mouse_released(x, y, button, istouch) = (router.mouse_released(x, y, button) unless istouch)

      def touch_pressed(id, x, y, devicetype, mouse) = (router.touch_pressed(id, x, y) if finger?(devicetype, mouse))
      def touch_moved(id, x, y, devicetype, mouse) = (router.touch_moved(id, x, y) if finger?(devicetype, mouse))
      def touch_released(id, x, y, devicetype, mouse) = (router.touch_released(id, x, y) if finger?(devicetype, mouse))

      # The game's name for the gamepad button LÖVE calls +name+, or nil.
      def button(name) = BUTTONS[name.to_s.to_sym]

      # :left or :right for the trigger axis LÖVE calls +axis+, or nil for
      # another axis.
      def trigger(axis) = TRIGGERS[axis.to_s]

      def gamepad_pressed(cursor) = router.gamepad_pressed(cursor)
      def gamepad_released(cursor) = router.gamepad_released(cursor)

      private

      def finger?(devicetype, mouse) = devicetype.to_s == "touchscreen" && mouse != true
    end
  end
end
