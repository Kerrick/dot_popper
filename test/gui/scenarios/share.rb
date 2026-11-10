# frozen_string_literal: true

module DotPopperGui
  # Game Over's "Share my score": it rises in once the score lands, and
  # opens a preview of the result that leaves the system's clipboard
  # alone until Copy is pressed, by a click, a finger, Enter, or a
  # gamepad's Y. The preview closes by Close, Escape, B, and a tap beside
  # its card, back to Game Over, and Home goes on as ever.
  class ShareScenario < Scenario
    scenario :share
    UNTOUCHED = "what the player had copied before"

    def play
      start_game
      pop_fresh
      run_out_the_clock
      wait(DotPopper::Presentation::Style::GAME_OVER.tally.duration + 1.0)
      check(screenshot.lit_in(show.share_reach) > 50, "Share my score is drawn")
      keep_screenshot("share-button")
      L::System.clipboard_text = UNTOUCHED
      open_by(:click)
      check_equal(UNTOUCHED, L::System.clipboard_text, "opening the preview leaves the clipboard alone")
      wait(0.5)
      keep_screenshot("share-preview")
      copy = show.copy_reach
      click(copy.center_x, copy.center_y)
      check_equal(show.share_preview.text, clipboard, "a click on Copy copies exactly the text shown")
      wait(0.5)
      keep_screenshot("share-copied")
      key(:escape)
      closed("Escape")
      by_keys_and_pad
      by_touch
      continue_to_home
    end

    private

    def open_by(how)
      share = show.share_reach
      how == :touch ? touch(share.center_x, share.center_y) : click(share.center_x, share.center_y)
      check(show.sharing?, "a #{how} on Share my score opens the preview")
    end

    def closed(how)
      check(!show.sharing? && show.game_over?, "#{how} closes the preview, back to Game Over")
    end

    def by_keys_and_pad
      L::System.clipboard_text = UNTOUCHED
      pad(:y)
      check(show.sharing? && L::System.clipboard_text == UNTOUCHED, "a gamepad's Y opens the preview, copying nothing")
      check_equal("Copy (A)", words.copy, "the preview names a gamepad's buttons")
      pad(:y)
      check_equal(show.share_preview.text, clipboard, "Y again copies")
      pad(:b)
      closed("a gamepad's B")
      open_by(:click)
      L::System.clipboard_text = UNTOUCHED
      key(:return)
      check_equal(show.share_preview.text, clipboard, "Enter copies")
      check(show.game_over?, "and stays on Game Over")
      close = show.close_reach
      click(close.center_x, close.center_y)
      closed("a click on Close")
    end

    def by_touch
      open_by(:touch)
      L::System.clipboard_text = UNTOUCHED
      copy = show.copy_reach
      touch(copy.center_x, copy.center_y)
      check_equal(show.share_preview.text, clipboard, "a tap on Copy copies")
      card = show.share_plan.card
      touch(card.center_x, card.y + 4)
      check(show.sharing?, "a tap on the card does nothing")
      touch(layout.safe.x + 6, layout.safe.bottom - 6)
      closed("a tap beside the card")
    end

    # The clipboard's text, its lines ended as the game wrote them: on
    # Windows the system hands back each line ended with CR LF, as every
    # Windows program writes text there, and a paste reads the same lines.
    def clipboard = L::System.clipboard_text.to_s.gsub("\r\n", "\n")
  end
end
