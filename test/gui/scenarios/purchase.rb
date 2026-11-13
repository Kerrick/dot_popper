# frozen_string_literal: true

module DotPopperGui
  # A free player's whole road to Pro in a computer's test build, on the
  # code a website build runs: the games run out, Play leads to the offer,
  # Buy goes to the fake checkout, which puts a signed test license key on
  # the clipboard, Paste license key enters it, and the thanks and the pro
  # features follow. It needs DOT_POPPER_FREE_GAMES=1, since a scenario
  # counts no games otherwise. PurchaseKeptScenario, run next on the same
  # save (DOT_POPPER_SAVE_AS), checks a relaunch.
  class PurchaseScenario < Scenario
    scenario :purchase

    def play
      keeper = show.instance_variable_get(:@theme_keeper)
      keeper.told(keeper.arrival) until keeper.arrival.nil?
      check(show.home?, "the game opens on Home")
      check_equal(words.games_left(2), show.games_line, "Home counts the games left")
      quick_game
      quick_game
      check_equal(words.games_left(0), show.games_line, "the games have run out")
      keep_screenshot("purchase-out-of-games")
      reach = show.play_reach
      click(reach.center_x, reach.center_y)
      check(show.offer?, "Play leads to the offer")
      wait_for("the store's price") { show.offer_price }
      check_equal("$1.99", show.offer_price, "the store gave its price")
      wait(0.5)
      keep_screenshot("purchase-offer")
      buy = show.reach_of(:buy)
      click(buy.center_x, buy.center_y)
      check(show.offer_status == words.offer[:copied], "Buy reaches the checkout, which sends a license key")
      paste = show.reach_of(:paste)
      click(paste.center_x, paste.center_y)
      wait_for("the thanks") { show.offer_status == words.offer[:thanks] }
      keep_screenshot("purchase-thanks")
      check_equal(%i[back], show.controls.map(&:name), "the offer leaves only Back")
      pro
    end

    private

    def pro
      show.back
      check(show.home?, "Back returns to Home")
      check_nil_games
      start_game
      check(show.playing?, "Play starts a game with no games left")
      run_out_the_clock
      continue_to_home
      show.open_stats
      check(!show.controls.map(&:name).include?(:offer), "the Stats screen no longer offers the purchase")
      check(!show.themes_locked?, "the themes are the player's to use")
      check(pro?, "the player has Pro, so Join and Create are theirs")
      show.open_themes
      check(show.themes?, "Themes opens")
      wait(0.5)
      keep_screenshot("purchase-pro-looks")
    end

    def check_nil_games = check(show.games_line.nil?, "Home no longer counts games")
  end

  # The purchase kept: the same save, a new launch, and the license key
  # still there.
  class PurchaseKeptScenario < Scenario
    scenario :purchase_kept

    def play
      check(show.home?, "the game opens on Home")
      check(show.games_line.nil?, "still Pro after a relaunch: Home counts no games")
      wait(0.5)
      keep_screenshot("purchase-relaunched")
      start_game
      check(show.playing?, "Play starts a game")
    end
  end
end
