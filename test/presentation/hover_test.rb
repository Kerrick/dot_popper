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

  def test_game_over_hovers_share_my_score_and_a_game_hovers_nothing
    press_main
    assert_empty @show.controls
    @cabinet.update(20)
    @show.update(0.1)
    @show.pointer_at(*middle(@show.share_reach))
    assert_equal :share, @show.hovered
    @show.pointer_at(*middle(@show.play_again_reach))
    assert_equal :play_again, @show.hovered
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
