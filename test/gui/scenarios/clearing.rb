# frozen_string_literal: true

module DotPopperGui
  # Clearing the records from the Stats screen: a press of "Clear my
  # records…" let go too soon changes nothing; held two seconds, by a
  # finger or a gamepad's Y, it clears them, and Undo puts them back. The
  # playtest log stays as it was throughout.
  class ClearingScenario < Scenario
    scenario :clearing

    HOLD = DotPopper::Presentation::Style::STATS_CLEAR.hold
    FILES = %w[score_record.txt stats.txt games.csv].freeze

    def play
      quick_game
      open_stats
      before = files
      check(!show.stats.empty, "the Stats screen lists the game")

      let_go_too_soon(before)
      hold_by_touch
      check_cleared(before)
      undo = show.undo_reach
      click(undo.center_x, undo.center_y)
      check(show.stats? && !show.stats.empty, "Undo brings the records back, and stays on the Stats screen")
      check(before == files, "Undo restores every file exactly")

      pad_down(:y)
      wait(HOLD + 0.1)
      pad_up(:y)
      check(show.stats.empty && show.undo_offer, "holding a gamepad's Y clears the records too")
      pad(:y)
      check(!show.stats.empty, "a press of Y undoes")
      back = show.back_reach
      click(back.center_x, back.center_y)
      check(!show.stats? && show.home?, "a click on Back goes back")
    end

    private

    def files = FILES.to_h { [it, File.read(saved(it))] }

    def open_stats
      reach = show.stats_reach
      click(reach.center_x, reach.center_y)
      check(show.stats?, "a click on Your stats opens them")
    end

    def let_go_too_soon(before)
      reach = show.clear_reach
      press(reach.center_x, reach.center_y)
      wait(HOLD / 2)
      check(show.stats? && show.clearing.held?, "a press on Clear my stats starts a hold and never goes back")
      keep_screenshot("clearing-held")
      release(reach.center_x, reach.center_y)
      wait(HOLD)
      check(!show.stats.empty && !show.undo_offer, "letting go too soon clears nothing")
      check(before == files, "letting go too soon leaves every file as it was")
    end

    def hold_by_touch
      reach = show.clear_reach
      touch_down(reach.center_x, reach.center_y)
      wait(HOLD + 0.1)
      touch_up(reach.center_x, reach.center_y)
    end

    def check_cleared(before)
      check(show.stats? && show.stats.empty, "held two seconds, the records clear, to the empty Stats screen")
      check(show.undo_offer, "Undo is offered")
      wait(0.3)
      keep_screenshot("clearing-cleared")
      check_equal("", File.read(saved("stats.txt")), "stats.txt is emptied")
      check(before["games.csv"] == File.read(saved("games.csv")), "the playtest log is untouched")
      backup = Dir[saved("stats-*.txt").tr("\\", "/")] # Dir[] reads only forward slashes, and Windows' save folder has back ones
      check_equal(1, backup.size, "one backup of stats.txt")
      check(before["stats.txt"] == File.read(backup.first), "the backup is an exact copy")
      check_equal(0, show.marquee.score_record, "the title's best is cleared too")
    end
  end
end
