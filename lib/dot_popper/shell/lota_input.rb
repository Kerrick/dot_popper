# frozen_string_literal: true

module DotPopper
  module Shell
    # Lota's input callbacks, in the game's own terms, for
    # Presentation::InputRouter (+router+). A finger on a touchscreen fires
    # touchpressed, and SDL then also makes up a mousepressed for it with
    # +istouch+ true; only the touch counts, so one finger is one tap. A
    # touch whose +devicetype+ isn't a touchscreen (a trackpad's, with 0 to
    # 1 coordinates), or that came from the mouse (+mouse+), is no finger.
    class LotaInput < Data.define(:router)
      def initialize(router: Presentation::InputRouter.new) = super

      def mouse_pressed(x, y, button, istouch) = (router.mouse_pressed(x, y, button) unless istouch)
      def mouse_moved(x, y, istouch) = (router.mouse_moved(x, y) unless istouch)
      def mouse_released(x, y, button, istouch) = (router.mouse_released(x, y, button) unless istouch)

      def touch_pressed(id, x, y, devicetype, mouse) = (router.touch_pressed(id, x, y) if finger?(devicetype, mouse))
      def touch_moved(id, x, y, devicetype, mouse) = (router.touch_moved(id, x, y) if finger?(devicetype, mouse))
      def touch_released(id, x, y, devicetype, mouse) = (router.touch_released(id, x, y) if finger?(devicetype, mouse))

      def gamepad_pressed(cursor) = router.gamepad_pressed(cursor)
      def gamepad_released(cursor) = router.gamepad_released(cursor)

      private

      def finger?(devicetype, mouse) = devicetype.to_s == "touchscreen" && mouse != true
    end
  end
end
