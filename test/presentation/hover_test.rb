# frozen_string_literal: true

require_relative "presentation_helper"

# The mouse over a button: which one it is over, from the same reaches
# taps use, and how each brightens and dims.
class HoverTest < Minitest::Test
  include PresentationTest

  LOOK = Look::HOVER
  STANDARD = DotPopper::DotSizing::STANDARD

  def setup
    @sounds = FakeSounds.new
    @game = DotPopper::Game.new(field, random: Random.new(2))
    @show = Show.new(game: @game, layout:, sounds: @sounds, radius: R, random: Random.new(3))
  end

  def test_a_level_eases_up_while_over_and_back_down_once_left
    hover = Hover.none.at(:records)
    hover = hover.update(LOOK.seconds / 2, LOOK)
    assert_in_delta Ease.out_quad(0.5), hover.level(:records)
    hover = hover.update(LOOK.seconds, LOOK)
    assert_in_delta 1.0, hover.level(:records)

    hover = hover.at(nil).update(LOOK.seconds / 4, LOOK)
    assert_in_delta Ease.out_quad(0.75), hover.level(:records)
    hover = hover.update(LOOK.seconds, LOOK)
    assert_in_delta 0.0, hover.level(:records)
    assert_empty hover.levels, "a dimmed button is forgotten"
  end

  # Moving from one button to the next, one dims as the other lights; and
  # coming back before it has dimmed picks up where it was.
  def test_moving_between_buttons_never_jumps
    hover = Hover.none.at(:mute).update(LOOK.seconds, LOOK)
    hover = hover.at(:records).update(LOOK.seconds / 4, LOOK)
    assert_in_delta Ease.out_quad(0.75), hover.level(:mute)
    assert_in_delta Ease.out_quad(0.25), hover.level(:records)

    hover = hover.at(:mute).update(LOOK.seconds / 4, LOOK)
    assert_in_delta 1.0, hover.level(:mute)
    assert_in_delta 0.0, hover.level(:records)
  end

  def test_the_title_hovers_the_buttons_it_offers_where_taps_reach_them
    mute = @show.layout.mute_button
    assert_equal :mute, @show.control_at(mute.center_x, mute.center_y).name
    assert_nil @show.records_reach, "a first title offers no records"
    assert_nil @show.control_at(*middle(@show.layout.records_button))

    finish_round
    assert_equal :records, @show.control_at(*middle(@show.records_reach)).name
    assert_equal :records, @show.control_at(@show.records_reach.x + 1, @show.records_reach.bottom - 1).name,
                 "the whole reach, not only the drawn pill"
    assert_equal STANDARD, @show.control_at(*middle(@show.sizing_reaches.to_h.fetch(STANDARD))).name
    assert_equal :play, @show.control_at(*middle(@show.play_reach)).name
    assert_nil @show.control_at(5, 5)
  end

  def test_the_mouse_over_a_button_lights_it_and_moving_away_dims_it
    finish_round
    @show.pointer_at(*middle(@show.records_reach))
    assert_equal :records, @show.hovered
    @show.update(LOOK.seconds)
    assert_in_delta 1.0, @show.hover.level(:records)

    @show.pointer_at(5, 5)
    assert_nil @show.hovered
    @show.update(LOOK.seconds)
    assert_in_delta 0.0, @show.hover.level(:records)
  end

  def test_only_the_mouse_hovers
    @show.pointer_at(*middle(@show.layout.mute_button))
    assert_equal :mute, @show.hovered

    @show.input = InputKind::TOUCH
    assert_nil @show.hovered
    @show.input = InputKind::GAMEPAD
    assert_nil @show.hovered
    @show.input = InputKind::MOUSE
    assert_equal :mute, @show.hovered

    @show.pointer_gone
    assert_nil @show.hovered
  end

  def test_the_records_screen_hovers_back_licences_and_clear_and_nothing_else
    finish_round
    @show.open_records
    assert_equal %i[licences clear back], @show.controls.map(&:name)
    @show.pointer_at(*middle(@show.back_reach))
    assert_equal :back, @show.hovered
    @show.pointer_at(*middle(@show.clear_reach))
    assert_equal :clear, @show.hovered
    @show.pointer_at(*middle(@show.title_plan.play_button))
    assert_nil @show.hovered, "the title's buttons are covered"
  end

  def test_game_over_hovers_copy_my_result_and_a_round_hovers_nothing
    press_main
    assert_empty @show.controls
    @game.update(20)
    @show.update(0.1)
    @show.pointer_at(*middle(@show.share_reach))
    assert_equal :share, @show.hovered
    @show.pointer_at(*middle(@show.continue_reach))
    assert_equal :continue, @show.hovered
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]

  def finish_round
    press_main
    @game.update(20)
    @game.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end
end
