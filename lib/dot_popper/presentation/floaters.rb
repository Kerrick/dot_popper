# frozen_string_literal: true

module DotPopper
  module Presentation
    # How a floating number moves: how far it rises (radii), and how long
    # it lives (seconds).
    class FloaterLook < Data.define(:rise, :life)
      def rise_tween = Tween.new(from: 0.0, to: rise, duration: life, ease: :out_cubic)
    end

    # A short piece of text, such as "+1" or "−2s", rising since +born+
    # from where it happened and fading fast. +scale+ is the radius in
    # graphics units.
    class Floater < Data.define(:text, :x, :y, :color, :look, :scale, :born)
      def alive?(now) = now - born < look.life

      def y_at(now) = y - (look.rise_tween.at(now - born) * scale)

      # Fully there for its first third, then gone quickly.
      def alpha(now)
        progress = ((now - born) / look.life).clamp(0.0, 1.0)
        1 - Ease.in_quad(((progress - 0.35) / 0.65).clamp(0.0, 1.0))
      end
    end
  end
end
