# frozen_string_literal: true

module DotPopper
  module Presentation
    # What the window is, in one line, printed as the game starts and on
    # every resize or rotation, so a run on a real device can be set
    # beside an SDL test program's on the same one: its size in graphics
    # units and in pixels, the scale between them as Lota reports it and
    # as the display has it natively, the safe area, and the window's
    # mode. +mode+ is [width, height, flags], the flags a Hash of whichever
    # of :fullscreen, :fullscreentype, :highdpi and :usedpiscale Lota has.
    #
    #   screen 812x375 units, 2436x1125 pixels, dpi scale 3.0 (native 3.0),
    #   safe area 47,0,718,354, mode 812x375 fullscreen desktop
    class ScreenReport < Data.define(:units, :pixels, :dpi_scale, :native, :safe, :mode)
      def to_s
        "screen #{size(units)} units, #{size(pixels)} pixels, dpi scale #{number(dpi_scale)} " \
          "(native #{number(native)}), safe area #{safe.map { number(it) }.join(",")}, mode #{mode_text}"
      end

      private

      def mode_text
        width, height, flags = mode
        parts = ["#{size([width, height])} #{flags[:fullscreen] ? "fullscreen #{flags[:fullscreentype]}" : "windowed"}"]
        parts << "highdpi #{flags[:highdpi]}" if flags.key?(:highdpi)
        parts << "usedpiscale #{flags[:usedpiscale]}" if flags.key?(:usedpiscale)
        parts.join(", ")
      end

      def size(pair) = pair.map { number(it) }.join("x")

      # Whole numbers as they are, and a Float to at most four places, so
      # 2.88 reads 2.88 and 3.0 reads 3.0.
      def number(value) = value.is_a?(Float) ? value.round(4).to_s : value.to_s
    end
  end
end
