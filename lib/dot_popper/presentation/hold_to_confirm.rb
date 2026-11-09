# frozen_string_literal: true

module DotPopper
  module Presentation
    # Clearing the records: how long "Clear my records…" must be held,
    # how long Undo is offered once they are cleared, and how long the
    # hint to hold stays after a press let go too soon.
    class ClearStyle < Data.define(:hold, :undo, :hint); end

    # A press that does something only once it has been held for
    # +seconds+, so it is never done by accident: let go sooner, and
    # nothing happens. +since+ is when the press began, nil while nothing
    # holds it, and +by+ what holds it (a finger's id, :mouse, :gamepad,
    # or :y), so letting go of something else changes nothing. +let_go+
    # is when the last press was let go too soon, for a hint that it must
    # be held.
    class HoldToConfirm < Data.define(:seconds, :since, :by, :let_go)
      def self.idle(seconds) = new(seconds:, since: nil, by: nil, let_go: nil)

      def held? = !since.nil?

      # Held by +by+ from +now+; a second press while held adds nothing.
      def press(by, now) = held? ? self : with(since: now, by:, let_go: nil)

      # +by+ let go at +now+. If it was what held it, and it was let go
      # too soon, the hold ends with nothing done.
      def release(by, now)
        return self unless held? && by == self.by

        with(since: nil, by: nil, let_go: now)
      end

      # Nothing holds it any more, and no hint is due: the screen went
      # away, or the hold was done.
      def cancel = self.class.idle(seconds)

      # How far the hold has come at +now+, from 0 to 1.
      def progress(now) = held? ? ((now - since) / seconds).clamp(0.0, 1.0) : 0.0

      # Whether it has been held long enough by +now+.
      def done?(now) = held? && now - since >= seconds

      # How long ago, at +now+, the last press was let go too soon, or nil.
      def let_go_ago(now) = let_go && (now - let_go)
    end

    # Undo, offered from +at+ for +seconds+ after the records were
    # cleared; +cleared+ is what RecordKeeper#restore puts back.
    class UndoOffer < Data.define(:cleared, :at, :seconds)
      def open?(now) = now < at + seconds

      # How much of the offer is left at +now+, from 1 down to 0.
      def left(now) = (1.0 - ((now - at) / seconds)).clamp(0.0, 1.0)
    end
  end
end
