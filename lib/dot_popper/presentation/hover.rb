# frozen_string_literal: true

module DotPopper
  module Presentation
    # One of a screen's buttons, where it is drawn (+frame+) and where a
    # press reaches it (+reach+, at least the frame): Home's :play,
    # :mute, :how_to_play and :stats, and on a desktop :fullscreen and
    # :quit, a segment of its dot-size choice (named by the DotSizing it
    # chooses), Game Over's :continue and :share, the share
    # preview's :copy and :close, and the Stats screen's :back, :clear
    # and :undo. The Show answers taps and
    # the mouse's hover from the same ones (Show#controls), so a button
    # lights up exactly where a click would press it.
    class Control < Data.define(:name, :frame, :reach)
      def initialize(name:, reach:, frame: reach) = super

      # +controls+ with their reaches cut back so that no two share a
      # point: where two reaches overlap, the overlap is split halfway
      # across the gap between the two buttons as drawn, along the way
      # they are set apart, so one press reaches one button, the nearer,
      # and every button keeps its own drawn shape.
      def self.apart(controls)
        list = controls.dup
        (0...list.size).to_a.combination(2) { |i, j| list[i], list[j] = list[i].split(list[j]) }
        list
      end

      # How far a press at +x+, +y+ is from the button as drawn: 0 on it.
      def distance(x, y)
        dx = [frame.x - x, 0.0, x - frame.right].max
        dy = [frame.y - y, 0.0, y - frame.bottom].max
        Math.hypot(dx, dy)
      end

      # This control and +other+, their reaches split where they overlap.
      def split(other)
        return [self, other] unless reach.overlaps?(other.reach)

        mine = frame
        theirs = other.frame
        down = [theirs.y - mine.bottom, mine.y - theirs.bottom].max
        across = [theirs.x - mine.right, mine.x - theirs.right].max
        return [self, other] if down.negative? && across.negative? # drawn over each other: nothing to split

        if down >= across then split_down(other, mine, theirs)
        else split_across(other, mine, theirs)
        end
      end

      private

      def split_down(other, mine, theirs)
        if mine.bottom <= theirs.y
          middle = (mine.bottom + theirs.y) / 2.0
          [cut(bottom: middle), other.cut(top: middle)]
        else
          middle = (theirs.bottom + mine.y) / 2.0
          [cut(top: middle), other.cut(bottom: middle)]
        end
      end

      def split_across(other, mine, theirs)
        if mine.right <= theirs.x
          middle = (mine.right + theirs.x) / 2.0
          [cut(right: middle), other.cut(left: middle)]
        else
          middle = (theirs.right + mine.x) / 2.0
          [cut(left: middle), other.cut(right: middle)]
        end
      end

      protected

      def cut(**edges) = with(reach: reach.cut(**edges))
    end

    # How a button shows the mouse over it: it brightens over +seconds+,
    # and dims as quickly once the mouse leaves. +fill+ is the color its
    # backing brightens to, and +edge+ the color of its outline then.
    class HoverStyle < Data.define(:seconds, :fill, :edge); end

    # Which button the mouse is over, and how lit each one is, from 0 to
    # 1. Each level eases toward 1 while the mouse is +over+ that button
    # and back toward 0 once it leaves, so moving from one button to the
    # next, or back again before it has dimmed, never jumps.
    class Hover < Data.define(:over, :levels)
      def self.none = new(over: nil, levels: {}.freeze)

      # The mouse is now over the button named +name+, or nil for none.
      def at(name) = name == over ? self : with(over: name)

      # +seconds+ later, every level a step nearer where it is going, by
      # +style+ (HoverStyle). A level that reaches 0 is forgotten.
      def update(seconds, style)
        step = style.seconds.positive? ? seconds / style.seconds : 1.0
        names = levels.keys | [over].compact
        moved = names.to_h { [it, (levels.fetch(it, 0.0) + (it == over ? step : -step)).clamp(0.0, 1.0)] }
        with(levels: moved.reject { |_, level| level.zero? }.freeze)
      end

      # How lit the button named +name+ is, eased: 0 for not at all.
      def level(name) = Ease.out_quad(levels.fetch(name, 0.0))
    end
  end
end
