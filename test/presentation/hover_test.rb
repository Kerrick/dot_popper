# frozen_string_literal: true

require_relative "presentation_helper"

# The mouse over a button: which one it is over, from the same reaches
# taps use, and how each brightens and dims.
class HoverTest < Minitest::Test
  include PresentationTest

  LOOK = Style::HOVER
  STANDARD = DotPopper::DotSizing::STANDARD

  def setup
    @sounds = FakeSounds.new
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @show = Show.new(cabinet: @cabinet, layout:, sounds: @sounds, radius: R, random: Random.new(3))
  end

  def test_a_level_eases_up_while_over_and_back_down_once_left
    hover = Hover.none.at(:stats)
    hover = hover.update(LOOK.seconds / 2, LOOK)
    assert_in_delta Ease.out_quad(0.5), hover.level(:stats)
    hover = hover.update(LOOK.seconds, LOOK)
    assert_in_delta 1.0, hover.level(:stats)

    hover = hover.at(nil).update(LOOK.seconds / 4, LOOK)
    assert_in_delta Ease.out_quad(0.75), hover.level(:stats)
    hover = hover.update(LOOK.seconds, LOOK)
    assert_in_delta 0.0, hover.level(:stats)
    assert_empty hover.levels, "a dimmed button is forgotten"
  end

  # Moving from one button to the next, one dims as the other lights; and
  # coming back before it has dimmed picks up where it was.
  def test_moving_between_buttons_never_jumps
    hover = Hover.none.at(:mute).update(LOOK.seconds, LOOK)
    hover = hover.at(:stats).update(LOOK.seconds / 4, LOOK)
    assert_in_delta Ease.out_quad(0.75), hover.level(:mute)
    assert_in_delta Ease.out_quad(0.25), hover.level(:stats)

    hover = hover.at(:mute).update(LOOK.seconds / 4, LOOK)
    assert_in_delta 1.0, hover.level(:mute)
    assert_in_delta 0.0, hover.level(:stats)
  end

  def test_the_title_hovers_the_buttons_it_offers_where_taps_reach_them
    mute = @show.layout.mute_button
    assert_equal :mute, @show.control_at(mute.center_x, mute.center_y).name
    assert_nil @show.stats_reach, "a first title offers no records"
    assert_nil @show.control_at(*middle(@show.layout.stats_button))

    finish_game
    assert_equal :stats, @show.control_at(*middle(@show.stats_reach)).name
    assert_equal :stats, @show.control_at(@show.stats_reach.x + 1, @show.stats_reach.bottom - 1).name,
                 "the whole reach, not only the drawn pill"
    assert_equal STANDARD, @show.control_at(*middle(@show.sizing_reaches.to_h.fetch(STANDARD))).name
    assert_equal :play, @show.control_at(*middle(@show.play_reach)).name
    assert_nil @show.control_at(5, 5)
  end

  def test_the_mouse_over_a_button_lights_it_and_moving_away_dims_it
    finish_game
    @show.pointer_at(*middle(@show.stats_reach))
    assert_equal :stats, @show.hovered
    @show.update(LOOK.seconds)
    assert_in_delta 1.0, @show.hover.level(:stats)

    @show.pointer_at(5, 5)
    assert_nil @show.hovered
    @show.update(LOOK.seconds)
    assert_in_delta 0.0, @show.hover.level(:stats)
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

  def test_the_stats_screen_hovers_back_credits_and_clear_and_nothing_else
    finish_game
    @show.open_stats
    assert_equal %i[credits achievements clear back], @show.controls.map(&:name)
    @show.pointer_at(*middle(@show.back_reach))
    assert_equal :back, @show.hovered
    @show.pointer_at(*middle(@show.clear_reach))
    assert_equal :clear, @show.hovered
    @show.pointer_at(*middle(@show.title_plan.play_button))
    assert_nil @show.hovered, "the title's buttons are covered"
  end

  def test_game_over_hovers_share_my_score_and_a_game_hovers_nothing
    press_main
    assert_empty @show.controls
    @cabinet.update(20)
    @show.update(0.1)
    @show.pointer_at(*middle(@show.share_reach))
    assert_equal :share, @show.hovered
    @show.pointer_at(*middle(@show.continue_reach))
    assert_equal :continue, @show.hovered
    @show.share
    @show.pointer_at(*middle(@show.copy_reach))
    assert_equal :copy, @show.hovered
    @show.pointer_at(*middle(@show.close_reach))
    assert_equal :close, @show.hovered
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]

  def finish_game
    press_main
    @cabinet.update(20)
    @cabinet.update(DotPopper::Rules::GAME_OVER_GRACE)
    press_main
  end
end
