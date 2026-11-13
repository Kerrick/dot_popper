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
