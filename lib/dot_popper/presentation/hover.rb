# frozen_string_literal: true

module DotPopper
  module Presentation
    # One of a screen's buttons, where a press reaches it: the title's
    # :mute and :records, a segment of its dot-size choice (named by the
    # DotSizing it chooses), Game Over's :share, and the Records screen's
    # :clear and :undo. The Show answers taps and the mouse's hover from
    # the same ones (Show#controls), so a button lights up exactly where a
    # click would press it.
    class Control < Data.define(:name, :reach); end

    # How a button shows the mouse over it: it brightens over +seconds+,
    # and dims as quickly once the mouse leaves. +fill+ is the colour its
    # backing brightens to, and +edge+ the colour of its outline then.
    class HoverLook < Data.define(:seconds, :fill, :edge); end

    # Which button the mouse is over, and how lit each one is, from 0 to
    # 1. Each level eases toward 1 while the mouse is +over+ that button
    # and back toward 0 once it leaves, so moving from one button to the
    # next, or back again before it has dimmed, never jumps.
    class Hover < Data.define(:over, :levels)
      def self.none = new(over: nil, levels: {}.freeze)

      # The mouse is now over the button named +name+, or nil for none.
      def at(name) = name == over ? self : with(over: name)

      # +seconds+ later, every level a step nearer where it is going, by
      # +look+ (HoverLook). A level that reaches 0 is forgotten.
      def update(seconds, look)
        step = look.seconds.positive? ? seconds / look.seconds : 1.0
        names = levels.keys | [over].compact
        moved = names.to_h { [it, (levels.fetch(it, 0.0) + (it == over ? step : -step)).clamp(0.0, 1.0)] }
        with(levels: moved.reject { |_, level| level.zero? }.freeze)
      end

      # How lit the button named +name+ is, eased: 0 for not at all.
      def level(name) = Ease.out_quad(levels.fetch(name, 0.0))
    end
  end
end
