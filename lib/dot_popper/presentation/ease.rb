# frozen_string_literal: true

module DotPopper
  module Presentation
    # Easing curves. Each takes progress from 0 to 1, clamped, and answers
    # how far along the motion is: 0 at the start and 1 at the end, though
    # out_back and out_elastic pass 1 on the way, which is the bounce.
    module Ease
      module_function

      def linear(t) = t.clamp(0.0, 1.0)

      def in_quad(t) = linear(t)**2

      def out_quad(t) = 1 - ((1 - linear(t))**2)

      def out_cubic(t) = 1 - ((1 - linear(t))**3)

      def in_out_sine(t) = -(Math.cos(Math::PI * linear(t)) - 1) / 2

      # Goes past the end and settles back, like a ball that bounces once.
      def out_back(t, overshoot = 1.70158)
        u = linear(t) - 1
        1 + ((overshoot + 1) * (u**3)) + (overshoot * (u**2))
      end

      # Springs past the end and back, a few times, smaller each time.
      def out_elastic(t)
        t = linear(t)
        return t if t.zero? || t == 1.0

        (2**(-10 * t) * Math.sin(((t * 10) - 0.75) * (2 * Math::PI / 3))) + 1
      end

      # The curve named +name+, such as :out_back.
      def by_name(name, t) = public_send(name, t)
    end
  end
end
