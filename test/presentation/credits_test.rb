# frozen_string_literal: true

require_relative "presentation_helper"

# The Credits screen's text, its lines, its scroll, and the way a Show
# opens, scrolls, and leaves it, with no window.
class CreditsTest < Minitest::Test
  include PresentationTest

  WORDS = Style::WORDS

  def test_the_book_is_in_order_and_skips_what_the_build_lacks
    full = Notices.new(ofl: "OFL", iosevka: "IOS", emoji: "NOTO", wordlists: "WORDS", lota: "LOTA", fledge: %w[ONE TWO])
    texts = CreditsBook.compose(WORDS, full).blocks.reject { it.kind == :note }.map(&:text)

    assert_equal ["Made by setdef", "Dot Popper © 2026 setdef", "Open-source licenses", "Fredoka", "OFL",
                  "Iosevka", "IOS", "Noto Emoji", "NOTO", "imsky/wordlists", "WORDS", "Lota", "LOTA", "Fledge", "ONE", "TWO"], texts

    bare = CreditsBook.compose(WORDS, Notices.none).blocks
    assert_equal ["Dot Popper © 2026 setdef", "Fredoka", "Iosevka", "Noto Emoji", "imsky/wordlists"], bare.select { it.kind == :subheading }.map(&:text),
                 "a heading with nothing under it goes"
    assert_includes bare.map(&:text).join(" "), "All rights reserved.", "the game keeps its rights"
  end

  # Dot Popper is proprietary: its notice is its copyright with all rights
  # reserved, while every open-source notice the build carries stays.
  def test_the_book_reserves_all_rights_and_keeps_the_open_source_notices
    full = Notices.new(ofl: "OFL TEXT", iosevka: "IOSEVKA TEXT", emoji: "NOTO TEXT", lota: "LOTA TEXT",
                       fledge: ["RUBY"])
    texts = CreditsBook.compose(WORDS, full).blocks.map(&:text).join(" ")

    assert_includes texts, "Dot Popper © 2026 setdef All rights reserved."
    %w[AGPL CC-BY-SA-4.0 Affero].each { refute_includes texts, it.delete("\\") }
    %w[OFL\ TEXT IOSEVKA\ TEXT NOTO\ TEXT LOTA\ TEXT RUBY].each { assert_includes texts, it.delete("\\") }
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

  # The maintainer: licenses are written to be read at their own line
  # breaks, so where the column has room, they are.
  HARD = "Permission is hereby granted, free of charge, to any person\nobtaining a copy of this software,\n\n" \
         "1. Neither the Font Software nor any of its components,\n   in Original or Modified Versions, may be sold.\n"

  def test_a_hard_wrapped_license_that_fits_is_shown_just_as_written
    book = CreditsBook.new(blocks: [CreditsBlock.new(:legal, HARD)])
    widest = CreditsLines.widest_as_written(book, size: 20, measure: RoughMeasure.new)
    lines = CreditsLines.set(book, size: 20, room: widest, line: 1.5, measure: RoughMeasure.new)

    assert_equal HARD.lines.map(&:rstrip).reject(&:empty?), lines.rows.map(&:text)
  end

  def test_a_hard_wrapped_license_too_wide_for_the_column_is_reflowed
    book = CreditsBook.new(blocks: [CreditsBlock.new(:legal, HARD)])
    widest = CreditsLines.widest_as_written(book, size: 20, measure: RoughMeasure.new)
    lines = CreditsLines.set(book, size: 20, room: widest - 1, line: 1.5, measure: RoughMeasure.new)

    refute_equal HARD.lines.map(&:rstrip).reject(&:empty?), lines.rows.map(&:text)
    lines.rows.each { assert_operator RoughMeasure.new.width(:mono, 20, it.text), :<, widest }
  end

  def test_a_license_written_to_be_reflowed_does_not_widen_the_page
    long = CreditsBook.new(blocks: [CreditsBlock.new(:legal, "word " * 60)])

    assert_in_delta 0.0, CreditsLines.widest_as_written(long, size: 20, measure: RoughMeasure.new)
  end

  def test_the_page_widens_for_a_license_as_far_as_the_screen_allows
    page = CreditsLayout.new(layout: layout(1600, 900), style: Style::CREDITS)
    wide = page.with(wanted: page.room + 100)
    huge = page.with(wanted: 10_000.0)

    assert_in_delta page.room + 100, wide.room, 1.0
    assert_operator huge.room, :<=, 1600
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

  # Opened from Settings, the Credits screen scrolls by the wheel, the
  # keys, a stick and a finger, and goes back a step at a time.
  def test_the_show_opens_scrolls_and_goes_back_a_step_at_a_time
    show = a_show
    show.open_settings
    reach = show.reach_of(:credits)
    show.tap(reach.center_x, reach.center_y)

    assert show.credits?
    assert_equal [:back], show.controls.map(&:name), "only Back, over the text"
    assert_operator show.credits.farthest, :>, 0.0

    show.wheel_scroll(-1)
    line = show.credits_layout.line
    assert_in_delta line * Style::CREDITS.wheel, show.credits.offset, 1e-6
    assert show.scroll_key(:page_down)
    refute show.scroll_key(:escape)
    show.stick_scroll(Stick.new(x: 0, y: 1.0), 1.0)
    assert_operator show.credits.offset, :>, line * 4
    before = show.credits.offset
    show.stick_scroll(Stick.new(x: 0, y: 0.1), 1.0)
    assert_equal before, show.credits.offset, "a stick inside its dead zone is at rest"

    show.tap(5, 300, by: 7)
    show.drag_scroll(7, 250)
    assert_in_delta before + 50, show.credits.offset, 1e-6, "a finger drags the page along"
    show.let_go(7)
    show.drag_scroll(7, 100)
    assert_in_delta before + 50, show.credits.offset, 1e-6

    assert show.back
    assert show.settings?
    assert show.back
    assert show.on_home?
  end

  def test_y_clears_nothing_while_credits_are_open
    show = a_show
    show.open_settings
    show.open_credits
    show.clear_or_undo(:y)

    refute show.clearing.held?
  end

  def test_a_resize_keeps_the_screen_open_and_laid_out_for_the_new_size
    show = a_show
    show.open_settings
    show.open_credits
    show.scroll_key(:end)
    show.resize(layout(400, 850), field(400, 850))

    assert show.credits?
    assert_in_delta show.credits_lines.height - show.credits_layout.window.height, show.credits.offset, 1e-6
  end

  private

  def a_show
    @sounds = FakeSounds.new
    notices = Notices.new(iosevka: Array.new(30) { "Some license words, #{it} " * 20 }.join("\n\n"), ofl: "Font text")
    cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    show = Show.new(cabinet:, layout: layout, sounds: @sounds, radius: R, notices:, measure: RoughMeasure.new)
    show.primary
    cabinet.update(30)
    show.update(1.0)
    cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    show.back
    show
  end
end
