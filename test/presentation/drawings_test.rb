# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "inputs"

# What each painter is handed: one value per screen that says everything
# it draws, where, and in which state, so the painters decide nothing a
# test could not see. Each is made again only when what it shows changes.
class DrawingsTest < Minitest::Test
  include PresentationTest

  P = DotPopper::Presentation

  def fixture(**) = Inputs::Fixture.new(os: "Linux", width: 1200, height: 800, **)

  # Over Settings, while setdef is gone: the heading and Back, the plan
  # the buttons' reaches come from, the buttons' words, and how lit each
  # is under the mouse.
  def test_change_server_says_its_words_and_how_lit_each_button_is
    fixture = fixture(gone: true)
    show = fixture.show
    show.open_settings
    show.screens.fetch(:server).open
    screen = show.screen
    drawing = screen.drawing
    words = show.words
    assert_equal words.button(:server_heading), drawing.header.text
    assert_equal words.go_back, drawing.header.back_word
    assert_equal show.layout.back_button, drawing.header.back
    assert_equal show.layout.heading_place(drawing.header.text, show.measure), [drawing.header.size, drawing.header.x]
    assert_equal [words.button(:server_paste), words.button(:server_reset)], [drawing.paste, drawing.reset]
    assert_equal screen.plan, drawing.plan
    assert_nil drawing.plan.reset, "nothing chosen, so nothing to reset"
    assert_equal [0.0, 0.0], [drawing.paste_hover, drawing.header.back_hover]

    paste = screen.controls.find { it.name == :server_paste }.frame
    show.pointer_at(paste.center_x, paste.center_y)
    fixture.tick(1.0)
    assert_in_delta 1.0, screen.drawing.paste_hover
  end

  # For a player the friend-group server knows: Delete, and under it how
  # to hold it, on one line where it fits, and wrapped to Delete's width
  # where it does not; the line goes while Delete is held, which fills.
  def test_privacy_says_how_to_hold_delete_and_how_far_it_is_held
    { [1200, 800] => false, [400, 850] => true }.each do |(width, height), wraps|
      fixture = Inputs::Fixture.new(os: "Linux", width:, height:, member: true)
      show = fixture.show
      show.open_settings
      show.open_privacy
      drawing = show.screen.drawing
      words = show.words
      assert_equal [words.button(:privacy_heading), words.button(:privacy_policy), words.button(:privacy_delete)],
                   [drawing.header.text, drawing.policy, drawing.delete]
      assert_equal words.button(:privacy_hold), drawing.hold_line
      assert_equal wraps, drawing.hold_rows.size > 1, "#{width}x#{height}"
      refute drawing.held

      show.pad(:y)
      fixture.tick(0.5)
      held = show.screen.drawing
      assert held.held
      assert_nil held.hold_line
      assert_in_delta 0.5 / GroupPanel::HOLD, held.progress, 0.05
      assert_equal drawing.hold_rows, held.hold_rows
    end
  end

  # For a player it does not know: no Delete, so nothing to hold.
  def test_privacy_without_a_friend_group_has_nothing_to_hold
    show = fixture.show
    show.open_settings
    show.open_privacy
    drawing = show.screen.drawing
    assert_nil drawing.plan.delete
    assert_nil drawing.hold_line
    assert_empty drawing.hold_rows
  end

  # Settings: each row's choices, which is chosen and how lit each is
  # under the mouse, and the part of the window its list shows in.
  def test_settings_says_each_choice_and_how_lit_it_is
    fixture = self.fixture
    show = fixture.show
    show.open_settings
    screen = show.screen
    drawing = screen.drawing
    assert_equal show.words.button(:settings_heading), drawing.header.text
    assert_equal(drawing.plan.rows.map { |row| row.choices.map { it.first(2) } }, drawing.choices.map { |row| row.map { it.first(2) } })
    page = show.layout.page
    assert_equal [page.y, page.height, show.layout.safe.width], [drawing.clip.y, drawing.clip.height, drawing.clip.width]
    assert_equal({ credits: 0.0, privacy: 0.0, server: 0.0 }, drawing.lit)

    off = screen.controls.find { it.name == [:sound, false] }.frame
    show.pointer_at(off.center_x, off.center_y)
    fixture.tick(1.0)
    lit = show.screen.drawing.choices.flatten(1).find { it.last == [:sound, false] }
    assert_in_delta 1.0, lit[2]
  end

  # Credits and licenses: the rows that show in its window at the
  # scroll's place, and where the scroll bar's thumb is.
  def test_credits_shows_the_rows_in_its_window_where_it_is_scrolled
    fixture = self.fixture
    show = fixture.show
    show.open_settings
    show.open_credits
    screen = show.screen
    top = screen.drawing
    window = top.window
    assert_equal show.words.button(:credits_heading), top.header.text
    assert_equal 0.0, top.offset
    refute_empty top.rows
    assert(top.rows.all? { it.y - window.height < window.height })
    assert_equal 0.0, top.thumb.first

    screen.scroll = screen.scroll.by(window.height)
    fixture.tick(0.1)
    down = screen.drawing
    assert_operator down.offset, :>, 0.0
    assert_equal screen.scroll.offset, down.offset
    refute_equal top.rows, down.rows
    assert_operator down.thumb.first, :>, 0.0
    assert_same down, screen.drawing
  end

  # The card telling of a new theme: the theme, its name, and the
  # switch's word, which for a Free player is Get Pro, as it opens the
  # offer.
  def test_the_new_theme_card_names_the_theme_and_what_its_switch_does
    { true => :use, false => :get_pro }.each do |pro, switch|
      show = fixture(arrival: true, pro:).show
      screen = show.screen
      assert_instance_of Screens::NewTheme, screen
      drawing = screen.drawing
      themes = show.words.themes
      assert_equal show.arrival, drawing.theme
      assert_equal [themes.fetch(:new), themes.fetch(drawing.theme.key), themes.fetch(:later)], [drawing.heading, drawing.name, drawing.later]
      use = switch == :use ? format(themes.fetch(:use), drawing.name) : show.words.offer.fetch(:entry)
      assert_equal use, drawing.use
      assert_equal screen.plan, drawing.plan
      safe = show.layout.safe
      assert_operator drawing.veil.x, :<, safe.x
      assert_operator drawing.veil.right, :>, safe.right
    end
  end

  # Nothing changed, nothing made: the same drawing, frame after frame.
  def test_change_server_is_not_made_again_while_nothing_changes
    fixture = fixture(gone: true)
    show = fixture.show
    show.open_settings
    show.screens.fetch(:server).open
    drawing = show.screen.drawing
    fixture.tick(0.5)
    assert_same drawing, show.screen.drawing
    assert_same drawing.plan, show.screen.plan
  end
end
