# frozen_string_literal: true

module DotPopper
  module Presentation
    # How soon, in seconds, and how near, in graphics units, a mouse
    # button's press may follow that button's last press and still be
    # its switch chattering (Chatter).
    class ChatterStyle < Data.define(:seconds, :reach); end

    # A worn mouse's switch chatters: one click reaches the game as two,
    # a few hundredths of a second apart, and the second lands on the
    # popped dot the first left behind. That loss is the mouse's, not the
    # player's, so a press of the same button too soon after its last
    # press, and too near it, to be a hand's is dropped, and so is its
    # release, so a drag never sees a stray one. It is dropped whatever
    # it would hit, on every screen. A press is never held back: it is
    # heard on its frame or not at all. Only the mouse chatters this way;
    # fingers and gamepads never come here.
    #
    # Each press is measured from the button's last press, dropped or
    # not, so a run of chatter is dropped whole. +presses+ holds each
    # button's last press as [at, x, y]; +dropping+, the buttons whose
    # next release is a dropped press's.
    class Chatter < Data.define(:style, :presses, :dropping)
      def self.quiet(style) = new(style:, presses: {}.freeze, dropping: [].freeze)

      # +button+ went down at +x+, +y+, +at+ seconds in. Returns the
      # Chatter after it, and whether the press is chatter, to be dropped.
      def press(button, x, y, at:)
        chatter = chatter?(presses[button], x, y, at)
        waiting = chatter ? dropping | [button] : dropping - [button]
        [with(presses: presses.merge(button => [at, x, y]).freeze, dropping: waiting.freeze), chatter]
      end

      # +button+ came up. Returns the Chatter after it, and whether the
      # release is a dropped press's, to be dropped too.
      def release(button)
        return [self, false] unless dropping.include?(button)

        [with(dropping: (dropping - [button]).freeze), true]
      end

      # No button is down any more, as when the window loses focus and a
      # release may never come: no release is dropped.
      def let_go = with(dropping: [].freeze)

      private

      def chatter?(last, x, y, at)
        return false unless last

        before, last_x, last_y = last
        at - before < style.seconds && Math.hypot(x - last_x, y - last_y) <= style.reach
      end
    end
  end
end
