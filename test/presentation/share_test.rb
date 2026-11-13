# frozen_string_literal: true

require_relative "presentation_helper"
require "platforms_helper"

# Sharing a result: "Share my score" comes in once the score lands, a
# little more strongly on a new record, and the preview it opens holds
# exactly the text Copy will copy, its emoji drawn as shapes.
class ShareTest < Minitest::Test
  include PresentationTest

  CUE = Style::GAME_OVER.share

  def test_a_line_of_the_result_breaks_into_words_and_shapes
    assert_equal [:bright, " 27 dots · ", :popped, " 1 mistake · ", :clock, " 38 seconds"],
                 ShareGlyphs.runs("🟡 27 dots · ⚫ 1 mistake · ⏱ 38 seconds")
    assert_equal ["Dot Popper: 25 points"], ShareGlyphs.runs("Dot Popper: 25 points")
    assert_in_delta 8 + (2 * ShareGlyphs::WIDTH * 20), ShareGlyphs.width("🟡 ab ⚫", 20) { it.length * 2.0 }
  end

  def test_the_preview_keeps_the_text_and_when_it_was_copied
    preview = SharePreview.open("Dot Popper: 3 points\nPlayed with dots sized to the screen.", 2.0)

    assert_equal ["Dot Popper: 3 points", "Played with dots sized to the screen."], preview.lines
    refute preview.copied?
    assert_in_delta 0.0, preview.confirmation(5.0, Style::SHARE_PREVIEW)
    copied = preview.copy(3.0)
    assert copied.copied?
    assert_in_delta 1.0, copied.confirmation(5.0, Style::SHARE_PREVIEW)
    assert_in_delta 1.0, copied.arrival(5.0, Style::SHARE_PREVIEW)
    assert_in_delta 0.0, copied.arrival(2.0, Style::SHARE_PREVIEW)
  end

  # The card says nothing about Copy before it is pressed, and keeps room
  # for "Copied! Paste it anywhere." and its check, so nothing moves when
  # it shows.
  def test_the_card_keeps_room_only_for_the_copied_line
    measure = RoughMeasure.new
    plan = ShareScreen.new(layout: layout(1200, 800), type: Style::TYPE, words: Style::WORDS, measure:,
                           style: Style::SHARE_PREVIEW, lines: ["Dot Popper: 3 points"]).plan
    size = plan.size(:note)
    copied = measure.width(:semibold, size, Style::WORDS.copied) + (measure.height(:semibold, size) * 0.75)

    assert_in_delta copied, plan[:note].width, 1e-9
    refute Style::WORDS.to_h.values.grep(String).any? { it.include?("Copy it") }, "no line on what Copy does"
  end

  def test_in_the_game_sharing_opens_the_preview
    preview = InGameSharing.new.offer("Dot Popper: 3 points", 4.0)

    assert_equal SharePreview.open("Dot Popper: 3 points", 4.0), preview
  end

  # An opener that remembers the URLs it was given, and takes them or not.
  class FakeOpener
    attr_reader :urls

    def initialize(takes:)
      @takes = takes
      @urls = []
    end

    def open(url)
      @urls << url
      @takes
    end
  end

  def test_a_phone_shares_through_its_own_sheet_and_a_computer_in_the_game
    opener = FakeOpener.new(takes: true)

    assert_equal SheetSharing.new(opener:, fallback: InGameSharing.new), SheetSharing.for(DotPopperTest.platform("iOS"), opener:)
    assert_equal SheetSharing.new(opener:, fallback: InGameSharing.new), SheetSharing.for(DotPopperTest.platform("Android"), opener:)
    ["OS X", "Windows", "Linux"].each { assert_equal InGameSharing.new, SheetSharing.for(DotPopperTest.platform(it), opener:) }
    assert_empty opener.urls
  end

  def test_the_sheet_s_url_carries_the_text_percent_encoded
    assert_equal "dotpopper-share://score?text=Dot%20Popper%3A%2025%20points%0A%F0%9F%9F%A1%201%2B1%26a%3Db%3F~._-",
                 SheetSharing.url("Dot Popper: 25 points\n🟡 1+1&a=b?~._-")
  end

  def test_a_sheet_that_takes_the_text_opens_no_preview
    opener = FakeOpener.new(takes: true)

    assert_nil SheetSharing.for(DotPopperTest.platform("iOS"), opener:).offer("Dot Popper: 3 points", 4.0)
    assert_equal [SheetSharing.url("Dot Popper: 3 points")], opener.urls
  end

  def test_a_sheet_that_will_not_open_falls_back_on_the_preview
    opener = FakeOpener.new(takes: false)

    assert_equal SharePreview.open("Dot Popper: 3 points", 4.0),
                 SheetSharing.for(DotPopperTest.platform("Android"), opener:).offer("Dot Popper: 3 points", 4.0)
  end

  def test_share_my_score_rises_into_place_once_the_score_has_landed
    before = ShareCue.at(-0.1, CUE)
    assert_in_delta 0.0, before.alpha
    assert_in_delta 0.0, before.ring_alpha

    rising = ShareCue.at(0.05, CUE)
    assert_operator rising.alpha, :>, 0.0
    assert_operator rising.drop, :>, 0.0, "it starts below its place"

    settled = ShareCue.at(5.0, CUE)
    assert_in_delta 1.0, settled.alpha
    assert_in_delta 0.0, settled.drop, 1e-9
    assert_in_delta 0.0, settled.ring_alpha, 1e-9, "the ring has faded"
  end

  def test_on_a_new_score_record_it_comes_a_little_later_and_more_strongly
    plain = ShareCue.at(0.05, CUE)
    score_record = ShareCue.at(0.05 + CUE.score_record_delay, CUE, score_record: true)
    assert_operator score_record.drop, :>, plain.drop

    ringing = CUE.arrive.duration * 0.6
    plain_ring = ShareCue.at(ringing, CUE)
    score_record_ring = ShareCue.at(ringing + CUE.score_record_delay, CUE, score_record: true)
    assert_operator score_record_ring.ring_alpha, :>, plain_ring.ring_alpha
    assert_operator score_record_ring.ring, :>, plain_ring.ring
  end

  def test_the_game_over_starts_the_cue_when_the_score_has_counted
    game_over = GameOver.new(style: Style::GAME_OVER, score: 9, score_record: 12, new_score_record: false, at: 1.0)

    assert_in_delta 0.0, game_over.share_cue(1.0 + Style::GAME_OVER.tally.duration).alpha
    assert_in_delta 1.0, game_over.share_cue(1.0 + Style::GAME_OVER.tally.duration + 2.0).alpha
  end
end
