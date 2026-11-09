# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the share preview looks: SHARE_PREVIEW in Style says each.
    class SharePreviewStyle < Data.define(:arrive, :confirm, :lift, :width, :pad, :bubble, :veil); end

    # The result to share, open over Game Over since +at+: the very +text+
    # Copy puts on the clipboard, shown before anything is copied, so the
    # player's clipboard changes only when they ask. +copied_at+ is when
    # Copy last copied it, or nil.
    class SharePreview < Data.define(:text, :at, :copied_at)
      def self.open(text, now) = new(text:, at: now, copied_at: nil)

      # The text's lines, as the message will show them.
      def lines = text.split("\n")

      def copy(now) = with(copied_at: now)
      def copied? = !copied_at.nil?

      # How far the preview has come in, by +style+ (SharePreviewStyle).
      def arrival(now, style) = style.arrive.at(now - at)

      # How far "Copied!" has come in since the last copy.
      def confirmation(now, style) = copied? ? style.confirm.at(now - copied_at) : 0.0
    end

    # How the game offers a result to share: in the game, by opening a
    # SharePreview, from which only Copy writes the clipboard. It is the
    # Show's +sharing+ on a computer; on a phone SheetSharing takes its
    # place, hands +text+ to the system's sheet and answers nil, so no
    # preview opens, and falls back on this one.
    class InGameSharing < Data.define
      def offer(text, now) = SharePreview.open(text, now)
    end

    # The shared result's emoji, which the game's fonts lack, so the
    # preview draws each as a shape in its place: the bright dot, the
    # popped dot, and a stopwatch. A line breaks into runs of words and
    # those shapes' names.
    module ShareGlyphs
      EMOJI = { "🟡" => :fresh, "⚫" => :popped, "⏱" => :clock }.freeze
      SPLIT = Regexp.union(EMOJI.keys)
      WIDTH = 1.15 # a shape's room in a line, in the line's height

      module_function

      # "🟡 27 dots" as [:fresh, " 27 dots"].
      def runs(line) = line.split(/(#{SPLIT})/o).reject(&:empty?).map { EMOJI.fetch(it, it) }

      # How wide +line+ is drawn, with each shape +height+ * WIDTH across
      # and the words as the block measures them.
      def width(line, height)
        runs(line).sum { it.is_a?(Symbol) ? height * WIDTH : yield(it) }
      end
    end
  end
end
