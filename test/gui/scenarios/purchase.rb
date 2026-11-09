# frozen_string_literal: true

module DotPopperGui
  # A free player's whole road to the paid version in a test build, on the
  # code a store build runs: the plays run out, Play leads to the offer,
  # Buy goes to the fake store and back, and the thanks and the paid
  # features follow. It needs DOT_POPPER_FREE_PLAYS=1, since a scenario
  # counts no plays otherwise. PurchaseKeptScenario, run next on the same
  # save (DOT_POPPER_SAVE_AS), checks a relaunch.
  class PurchaseScenario < Scenario
    scenario :purchase

    def play
      check(show.title?, "the game opens on the title")
      check_equal(words.plays_left(2), show.plays_line, "the title counts the plays left")
      quick_round
      quick_round
      check_equal(words.plays_left(0), show.plays_line, "the plays have run out")
      keep_screenshot("purchase-out-of-plays")
      reach = show.play_reach
      click(reach.center_x, reach.center_y)
      check(show.offer?, "Play leads to the offer")
      wait_for("the store's price") { show.offer_price }
      check_equal("$1.99", show.offer_price, "the store gave its price")
      wait(0.5)
      keep_screenshot("purchase-offer")
      buy = show.reach_of(:buy)
      click(buy.center_x, buy.center_y)
      check(show.offer_status == words.offer[:busy], "Buy waits for the store")
      wait_for("the thanks") { show.offer_status == words.offer[:thanks] }
      keep_screenshot("purchase-thanks")
      check_equal(%i[back], show.controls.map(&:name), "the offer leaves only Back")
      paid
    end

    private

    def paid
      show.back
      check(show.title?, "Back returns to the title")
      check_nil_plays
      start_round
      check(show.playing?, "Play starts a round with no plays left")
      run_out_the_clock
      continue_to_title
      show.open_records
      check(!show.controls.map(&:name).include?(:offer), "the Records screen no longer offers the purchase")
      check(!show.looks_locked?, "the looks are the player's to wear")
      check(show.group_panel.paid?, "the player can create a friend group")
      show.open_looks
      check(show.looks?, "Looks opens")
      wait(0.5)
      keep_screenshot("purchase-paid-looks")
    end

    def check_nil_plays = check(show.plays_line.nil?, "the title no longer counts plays")
  end

  # The purchase kept: the same save, a new launch, and no store to ask.
  class PurchaseKeptScenario < Scenario
    scenario :purchase_kept

    def play
      check(show.title?, "the game opens on the title")
      check(show.plays_line.nil?, "still Paid after a relaunch: the title counts no plays")
      wait(0.5)
      keep_screenshot("purchase-relaunched")
      start_round
      check(show.playing?, "Play starts a round")
    end
  end
end
