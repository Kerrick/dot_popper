# frozen_string_literal: true

require_relative "presentation_helper"

# The Credits screen's text, its lines, its scroll, and the way a Show
# opens, scrolls, and leaves it, with no window.
class CreditsTest < Minitest::Test
  include PresentationTest

  WORDS = Look::WORDS

  def test_the_book_is_in_order_and_skips_what_the_build_lacks
    full = Notices.new(agpl: "AGPL", ofl: "OFL", iosevka: "IOS", lota: "LOTA", fledge: %w[ONE TWO])
    texts = CreditsBook.compose(WORDS, full).blocks.reject { it.kind == :note }.map(&:text)

    assert_equal ["Made by setdef", "Dot Popper © 2026 setdef", "AGPL", "Open-source licenses", "Fredoka", "OFL",
                  "Iosevka", "IOS", "Lota", "LOTA", "Fledge", "ONE", "TWO"], texts

    bare = CreditsBook.compose(WORDS, Notices.none).blocks
    assert_equal ["Dot Popper © 2026 setdef", "Fredoka", "Iosevka"], bare.select { it.kind == :subheading }.map(&:text),
                 "a heading with nothing under it goes"
    assert_includes bare.map(&:text).join(" "), "CC0-1.0", "the sounds and icon are said to be CC0"
  end

  def test_a_line_of_thanks_comes_after_who_made_it_once_the_words_have_one
    assert_equal ["Made by setdef", "Dot Popper © 2026 setdef"],
                 CreditsBook.compose(WORDS, Notices.none).blocks.first(2).map(&:text).values_at(0, 1)
    thanks = WORDS.with(notice: WORDS.notice.merge(thanks: "Thanks to Ada."))

    assert_equal ["Made by setdef", "Thanks to Ada."], CreditsBook.compose(thanks, Notices.none).blocks.first(2).map(&:text)
  end

  def test_hard_wrapped_text_is_reflowed_and_lists_keep_their_lines
    text = "one two\nthree four\n\n----------\n\n  1. item a\n  2. item b\n"

    assert_equal [["one two three four"], ["  1. item a", "  2. item b"]], CreditsLines.paragraphs_of(text)
  end

  def test_no_line_is_wider_than_the_room_and_a_long_word_is_broken
    book = CreditsBook.new(blocks: [CreditsBlock.new(:legal, "a #{"w" * 200} b")])
    lines = CreditsLines.set(book, size: 20, room: 300, line: 1.5, measure: RoughMeasure.new)

    assert_operator lines.rows.size, :>, 3
    lines.rows.each { assert_operator RoughMeasure.new.width(:mono, 20, it.text), :<=, 300 }
    assert_in_delta 30.0 * lines.rows.size, lines.height, 1e-9
  end

  def test_a_wrapped_line_keeps_its_indentation_on_every_piece
    book = CreditsBook.new(blocks: [CreditsBlock.new(:legal, "    12. #{"word " * 20}")])
    lines = CreditsLines.set(book, size: 20, room: 300, line: 1.5, measure: RoughMeasure.new)

    assert_operator lines.rows.size, :>, 1
    lines.rows.each { assert_match(/\A {4}\S/, it.text) }
    lines.rows.each { assert_operator RoughMeasure.new.width(:mono, 20, it.text), :<=, 300 }
  end

  def test_scrolling_stays_on_the_page
    scroll = CreditsScroll.at_top(content: 1000.0, window: 400.0)

    assert_equal 0.0, scroll.by(-50).offset
    assert_equal 600.0, scroll.by(5000).offset
    assert_in_delta 360.0, scroll.page(1).offset, 1e-9
    assert_equal 600.0, scroll.key(:end, line: 30).offset
    assert_equal 0.0, scroll.key(:end, line: 30).key(:home, line: 30).offset
    assert_equal 30.0, scroll.key(:down, line: 30).offset
    assert_equal scroll, scroll.key(:x, line: 30)
    assert_nil CreditsScroll.at_top(content: 100.0, window: 400.0).thumb
    assert_equal [0.0, 0.4], scroll.thumb
    assert_in_delta 1.0, scroll.to_end.thumb.sum, 1e-9
  end

  def test_a_resize_keeps_the_same_place_in_the_page
    scroll = CreditsScroll.at_top(content: 1000.0, window: 400.0).by(300)

    assert_in_delta 750.0, scroll.fitted(content: 2000.0, window: 500.0).offset, 1e-9
  end

  def test_the_show_opens_scrolls_and_goes_back_a_step_at_a_time
    show = a_show
    show.open_records
    reach = show.reach_of(:credits)
    show.tap(reach.center_x, reach.center_y)

    assert show.credits?
    assert show.records?
    assert_equal [:back], show.controls.map(&:name), "only Back, over the text"
    assert_operator show.credits.farthest, :>, 0.0

    show.wheel_credits(-1)
    line = show.credits_layout.line
    assert_in_delta line * Look::CREDITS.wheel, show.credits.offset, 1e-6
    assert show.credits_key(:pagedown)
    refute show.credits_key(:escape)
    show.stick_credits(Stick.new(x: 0, y: 1.0), 1.0)
    assert_operator show.credits.offset, :>, line * 4
    before = show.credits.offset
    show.stick_credits(Stick.new(x: 0, y: 0.1), 1.0)
    assert_equal before, show.credits.offset, "a stick inside its dead zone is at rest"

    show.tap(5, 300, by: 7)
    show.drag_credits(7, 250)
    assert_in_delta before + 50, show.credits.offset, 1e-6, "a finger drags the page along"
    show.let_go(7)
    show.drag_credits(7, 100)
    assert_in_delta before + 50, show.credits.offset, 1e-6

    assert show.back
    refute show.credits?
    assert show.records?
    assert show.back
    refute show.records?
  end

  def test_y_clears_nothing_while_credits_are_open
    show = a_show
    show.open_records
    show.open_credits
    show.clear_or_undo(:y)

    refute show.clearing.held?
  end

  def test_a_resize_keeps_the_screen_open_and_laid_out_for_the_new_size
    show = a_show
    show.open_records
    show.open_credits
    show.credits_key(:end)
    show.resize(layout(400, 850), field(400, 850))

    assert show.credits?
    assert_in_delta show.credits_lines.height - show.credits_layout.window.height, show.credits.offset, 1e-6
  end

  private

  def a_show
    @sounds = FakeSounds.new
    notices = Notices.new(agpl: Array.new(30) { "Some license words, #{it} " * 20 }.join("\n\n"), ofl: "Font text")
    game = DotPopper::Game.new(field, random: Random.new(2))
    show = Show.new(game:, layout: layout, sounds: @sounds, radius: R, notices:, measure: RoughMeasure.new)
    show.primary
    game.update(30)
    show.update(1.0)
    game.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.primary
    show
  end
end
