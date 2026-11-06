# frozen_string_literal: true

require_relative "presentation_helper"

# The Licences screen's text, its lines, its scroll, and the way a Show
# opens, scrolls, and leaves it, with no window.
class LicencesTest < Minitest::Test
  include PresentationTest

  WORDS = Look::WORDS

  def test_the_book_is_in_order_and_skips_what_the_build_lacks
    full = Notices.new(agpl: "AGPL", ofl: "OFL", lota: "LOTA", fledge: %w[ONE TWO])
    texts = LicenceBook.compose(WORDS, full).blocks.reject { it.kind == :note }.map(&:text)

    assert_equal ["Dot Popper © 2026 Kerrick Long", "AGPL", "Fredoka", "OFL", "Lota", "LOTA", "Fledge", "ONE", "TWO"], texts

    bare = LicenceBook.compose(WORDS, Notices.none).blocks
    assert_equal ["Dot Popper © 2026 Kerrick Long", "Fredoka"], bare.select { it.kind == :heading }.map(&:text),
                 "a heading with nothing under it goes"
    assert_includes bare.map(&:text).join(" "), "CC0-1.0", "the sounds and icon are said to be CC0"
  end

  def test_hard_wrapped_text_is_reflowed_and_lists_keep_their_lines
    text = "one two\nthree four\n\n----------\n\n  1. item a\n  2. item b\n"

    assert_equal [["one two three four"], ["1. item a", "2. item b"]], LicenceLines.paragraphs_of(text)
  end

  def test_no_line_is_wider_than_the_room_and_a_long_word_is_broken
    book = LicenceBook.new(blocks: [LicenceBlock.new(:legal, "a #{"w" * 200} b")])
    lines = LicenceLines.set(book, size: 20, room: 300, line: 1.5, measure: RoughMeasure.new)

    assert_operator lines.rows.size, :>, 3
    lines.rows.each { assert_operator RoughMeasure.new.width(:semibold, 20, it.text), :<=, 300 }
    assert_in_delta 30.0 * lines.rows.size, lines.height, 1e-9
  end

  def test_scrolling_stays_on_the_page
    scroll = LicenceScroll.at_top(content: 1000.0, window: 400.0)

    assert_equal 0.0, scroll.by(-50).offset
    assert_equal 600.0, scroll.by(5000).offset
    assert_in_delta 360.0, scroll.page(1).offset, 1e-9
    assert_equal 600.0, scroll.key(:end, line: 30).offset
    assert_equal 0.0, scroll.key(:end, line: 30).key(:home, line: 30).offset
    assert_equal 30.0, scroll.key(:down, line: 30).offset
    assert_equal scroll, scroll.key(:x, line: 30)
    assert_nil LicenceScroll.at_top(content: 100.0, window: 400.0).thumb
    assert_equal [0.0, 0.4], scroll.thumb
    assert_in_delta 1.0, scroll.to_end.thumb.sum, 1e-9
  end

  def test_a_resize_keeps_the_same_place_in_the_page
    scroll = LicenceScroll.at_top(content: 1000.0, window: 400.0).by(300)

    assert_in_delta 750.0, scroll.fitted(content: 2000.0, window: 500.0).offset, 1e-9
  end

  def test_the_show_opens_scrolls_and_goes_back_a_step_at_a_time
    show = a_show
    show.open_records
    reach = show.reach_of(:licences)
    show.tap(reach.center_x, reach.center_y)

    assert show.licences?
    assert show.records?
    assert_equal [:back], show.controls.map(&:name), "only Back, over the text"
    assert_operator show.licences.farthest, :>, 0.0

    show.wheel_licences(-1)
    line = show.licences_layout.line
    assert_in_delta line * Look::LICENCES.wheel, show.licences.offset, 1e-6
    assert show.licence_key(:pagedown)
    refute show.licence_key(:escape)
    show.stick_licences(Stick.new(x: 0, y: 1.0), 1.0)
    assert_operator show.licences.offset, :>, line * 4
    before = show.licences.offset
    show.stick_licences(Stick.new(x: 0, y: 0.1), 1.0)
    assert_equal before, show.licences.offset, "a stick inside its dead zone is at rest"

    show.tap(5, 300, by: 7)
    show.drag_licences(7, 250)
    assert_in_delta before + 50, show.licences.offset, 1e-6, "a finger drags the page along"
    show.let_go(7)
    show.drag_licences(7, 100)
    assert_in_delta before + 50, show.licences.offset, 1e-6

    assert show.back
    refute show.licences?
    assert show.records?
    assert show.back
    refute show.records?
  end

  def test_y_clears_nothing_while_licences_are_open
    show = a_show
    show.open_records
    show.open_licences
    show.clear_or_undo(:y)

    refute show.clearing.held?
  end

  def test_a_resize_keeps_the_screen_open_and_laid_out_for_the_new_size
    show = a_show
    show.open_records
    show.open_licences
    show.licence_key(:end)
    show.resize(layout(400, 850), field(400, 850))

    assert show.licences?
    assert_in_delta show.licence_lines.height - show.licences_layout.window.height, show.licences.offset, 1e-6
  end

  private

  def a_show
    @sounds = FakeSounds.new
    notices = Notices.new(agpl: Array.new(30) { "Some licence words, #{it} " * 20 }.join("\n\n"), ofl: "Font text")
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
