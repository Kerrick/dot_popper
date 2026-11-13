# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Stats, over Home (StatsLayout): Back, and "Clear my stats…" or
      # Undo.
      class Stats < Page
        def controls
          [(button(:undo, layout.undo_button) if show.undo_offer),
           (button(:clear, layout.clear_stats_button) if show.clear_offered?),
           back_button].compact
        end

        # Y: Undo while it is offered, or else hold to clear the stats.
        def pad(button) = (show.clear_or_undo(:y) if button == :y)

        def scrolls? = true
      end
    end
  end
end
