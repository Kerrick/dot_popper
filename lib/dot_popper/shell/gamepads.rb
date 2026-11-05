# frozen_string_literal: true

module DotPopper
  module Shell
    # The connected gamepads, and the push of their left sticks and d-pads
    # each frame. Lota binds controllers from 0.1.3; on an older Lota no
    # gamepad is ever added, and every stick is at rest.
    #
    # The pads are the ones Lota's joystickadded and joystickremoved
    # callbacks hand over, kept here, rather than Lota::Joystick.joysticks
    # asked for every frame: the list changes only when a controller comes
    # or goes, and asking for it each frame made fresh wrappers that Lota
    # trunk could hand out after freeing (on iOS, where SDL presents the
    # accelerometer as a joystick, that crashed the game). Phones and
    # tablets take no controllers at all, so they never touch a joystick.
    class Gamepads
      def initialize(enabled: true)
        @enabled = enabled
        @pads = []
      end

      def added(joystick)
        @pads << joystick if @enabled && joystick.gamepad? && !@pads.include?(joystick)
      end

      def removed(joystick) = @pads.delete(joystick)

      # The push of every gamepad's left stick and d-pad, together.
      def stick = @pads.sum(Presentation::Stick.rest) { push(it) }

      private

      def push(pad)
        Presentation::Stick.new(x: pad.gamepad_axis(:leftx), y: pad.gamepad_axis(:lefty)) +
          Presentation::Stick.dpad(left: pad.gamepad_down?(:dpleft), right: pad.gamepad_down?(:dpright),
                                   up: pad.gamepad_down?(:dpup), down: pad.gamepad_down?(:dpdown))
      end
    end
  end
end
