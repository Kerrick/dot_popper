# frozen_string_literal: true

module DotPopper
  module Presentation
    module Screens
      # Stats, over Home (StatsLayout): the sheet of every game's numbers
      # from +stats_book+ and the +achievements+, Back, and "Clear my
      # stats…", held to clear them through +keeper+ (StatsBackup), or
      # Undo for a while after.
      class Stats < Page
        def initialize(show, keeper:, stats_book:, achievements:, haptics:)
          super(show)
          @keeper = keeper
          @stats_book = stats_book
          @achievements = achievements
          @haptics = haptics
          @sheet = nil
          @clearing = HoldToConfirm.idle(show.style::STATS_CLEAR.hold)
          @undo = nil
        end

        # What it shows (StatsSheet), from when it was last opened.
        attr_reader :sheet

        # The hold of "Clear my stats…" (HoldToConfirm).
        attr_reader :clearing

        # Opens over Home, from the Stats as they are now.
        def open
          return unless show.on_home?

          refresh
          show.open_page(:stats)
        end

        # The sheet as the Stats are now.
        def refresh = @sheet = build_sheet

        # As Home shows: it shows nothing until opened again.
        def forget = @sheet = nil

        # Where its parts go (StatsLayout).
        def plan = StatsLayout.measured(layout:, sheet:, style: style::STATS, measure:)

        # Undo, while it is offered here (UndoableClear), or nil.
        def undo_offer = (@undo if show.stats?)

        # Whether it offers "Clear my stats…": while it has Stats to clear,
        # and no Undo is offered.
        def clear_offered? = show.stats? && !sheet.empty && !undo_offer

        # A gamepad's Y, held by +by+: Undo while it is offered, or else the
        # start of holding "Clear my stats…".
        def clear_or_undo(by)
          return undo if undo_offer

          hold_clear(by) if clear_offered?
        end

        def hold_clear(by)
          @clearing = clearing.press(by, show.now)
          sounds.play(:tick, pitch: 0.7)
        end

        # +by+ let go: a hold it made ends, with nothing cleared, if it was
        # let go too soon.
        def release(by) = @clearing = clearing.release(by, show.now)

        # Whatever holds "Clear my stats…" stops, with nothing cleared.
        def cancel_hold = @clearing = clearing.cancel

        # A game started: its records would be lost to an undo.
        def forget_undo = @undo = nil

        def undo
          @keeper.restore(@undo.cleared)
          @undo = nil
          changed
          sounds.play(:tick, pitch: 1.2)
        end

        # The moving parts of each frame: a hold done clears the Stats, and
        # Undo goes once its time is over.
        def update
          clear if clearing.done?(show.now)
          @undo = nil unless @undo&.open?(show.now)
        end

        # "Clear my stats…" was held long enough: Stats go, and Undo is
        # offered.
        def clear
          @clearing = clearing.cancel
          @undo = UndoableClear.new(cleared: @keeper.clear, at: show.now, seconds: style::STATS_CLEAR.undo)
          changed
          sounds.play(:bonk, pitch: 0.7)
          @haptics.buzz(style::HAPTICS.penalty)
        end

        def controls
          [(button(:undo, layout.undo_button) if undo_offer),
           (button(:clear, layout.clear_stats_button) if clear_offered?),
           back_button].compact
        end

        # Y: Undo while it is offered, or else hold to clear the stats.
        def pad(button) = (clear_or_undo(:y) if button == :y)

        def scrolls? = true

        def pressed(name, by)
          case name
          in :undo then undo
          in :clear then hold_clear(by)
          else super
          end
        end

        def empty(_x, y, by) = show.start_scroll(by, y)

        private

        # The Stats changed under it: it, and Home's score record, show them
        # as they are now.
        def changed
          refresh if show.stats?
          show.score_record_changed
        end

        def build_sheet
          cabinet = show.cabinet
          size_class = cabinet.size_class
          StatsSheet.build(@stats_book.stats, score_record: cabinet.score_record.of(size_class), words:, streak: @stats_book.streak,
                                              size_class:, field: cabinet.field, sizing: cabinet.sizing, preview: show.sizing_preview,
                                              achievements: @achievements)
        end
      end
    end
  end
end
