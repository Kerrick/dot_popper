# frozen_string_literal: true

module DotPopperGui
  # Clearing the records from the Records screen: a press of "Clear my
  # records…" let go too soon changes nothing; held two seconds, by a
  # finger or a gamepad's Y, it clears them, and Undo puts them back. The
  # playtest log stays as it was throughout.
  class ClearingScenario < Scenario
    scenario :clearing

    HOLD = DotPopper::Presentation::Look::RECORDS_CLEAR.hold
    FILES = %w[best_score.txt lifetime.txt rounds.csv].freeze

    def play
      quick_round
      open_records
      before = files
      check(!show.records.empty, "the Records screen lists the round")

      let_go_too_soon(before)
      hold_by_touch
      check_cleared(before)
      undo = show.undo_reach
      click(undo.center_x, undo.center_y)
      check(show.records? && !show.records.empty, "Undo brings the records back, and stays on the Records screen")
      check(before == files, "Undo restores every file exactly")

      pad_down(:y)
      wait(HOLD + 0.1)
      pad_up(:y)
      check(show.records.empty && show.undo_offer, "holding a gamepad's Y clears the records too")
      pad(:y)
      check(!show.records.empty, "a press of Y undoes")
      back = show.back_reach
      click(back.center_x, back.center_y)
      check(!show.records? && show.title?, "a click on Back goes back")
    end

    private

    def files = FILES.to_h { [it, File.read(saved(it))] }

    def open_records
      reach = show.records_reach
      click(reach.center_x, reach.center_y)
      check(show.records?, "a click on Your records opens them")
    end

    def let_go_too_soon(before)
      reach = show.clear_reach
      press(reach.center_x, reach.center_y)
      wait(HOLD / 2)
      check(show.records? && show.clearing.held?, "a press on Clear my records starts a hold and never goes back")
      keep_screenshot("clearing-held")
      release(reach.center_x, reach.center_y)
      wait(HOLD)
      check(!show.records.empty && !show.undo_offer, "letting go too soon clears nothing")
      check(before == files, "letting go too soon leaves every file as it was")
    end

    def hold_by_touch
      reach = show.clear_reach
      touch_down(reach.center_x, reach.center_y)
      wait(HOLD + 0.1)
      touch_up(reach.center_x, reach.center_y)
    end

    def check_cleared(before)
      check(show.records? && show.records.empty, "held two seconds, the records clear, to the empty Records screen")
      check(show.undo_offer, "Undo is offered")
      wait(0.3)
      keep_screenshot("clearing-cleared")
      check_equal("", File.read(saved("lifetime.txt")), "lifetime.txt is emptied")
      check(before["rounds.csv"] == File.read(saved("rounds.csv")), "the playtest log is untouched")
      backup = Dir[saved("lifetime-*.txt")]
      check_equal(1, backup.size, "one backup of lifetime.txt")
      check(before["lifetime.txt"] == File.read(backup.first), "the backup is an exact copy")
      check_equal(0, show.marquee.best, "the title's best is cleared too")
    end
  end
end
