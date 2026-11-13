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
      end
    end
  end
end
