# frozen_string_literal: true

require_relative "presentation_helper"

# The screens as objects on a stack (Screens, ADR-0018): the screen on top
# is the one object for it, each opens over the screen in view, and Back
# returns to the one it was opened over, as it was.
class ScreensTest < Minitest::Test
  include PresentationTest

  def setup
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @show = new_show(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, entitlement: DotPopper::Entitlement.free)
  end

  def test_the_screen_for_the_games_state_is_under_everything
    assert_equal Screens::Home, @show.screen.class
    assert @show.screens.fetch(:home).equal?(@show.state_screen)

    @show.how_to_play
    assert_equal Screens::Tutorial, @show.screen.class, "How to play opens the Tutorial over its game"
    @show.skip_tutorial
    assert_equal Screens::Game, @show.screen.class
    @cabinet.update(30)
    assert_equal Screens::GameOver, @show.screen.class
    assert_empty @show.layers
  end

  # Back closes the screen on top, and the one under it is on top again;
  # the stack is empty once Home is.
  def test_back_returns_to_the_screen_each_was_opened_over
    walks = [%i[open_stats], %i[open_themes], %i[open_settings open_credits], %i[open_settings open_privacy],
             [:open_achievements, [:open_achievement, :steady]], [:open_achievements, [:open_achievement, :steady], :achievement_pro]]
    walks.each do |walk|
      under = []
      walk.each do |step|
        under << @show.screen
        @show.public_send(*Array(step))
      end
      until under.empty?
        expected = under.pop
        expected = under.pop if walk.last == :achievement_pro && expected.is_a?(Screens::AchievementDialog)
        assert @show.back, walk.inspect
        assert expected.equal?(@show.screen), "#{walk.inspect}: back to #{expected.class}, not #{@show.screen.class}"
      end
      assert_empty @show.layers, walk.inspect
    end
  end

  # Each screen is made once, as the Show is, so asking which is on top
  # makes nothing.
  def test_each_screen_is_made_once
    before = @show.screens.values

    @show.open_stats
    @show.back
    @show.open_settings

    assert_equal before.map(&:object_id), @show.screens.values.map(&:object_id)
    assert @show.screen.equal?(@show.screen)
  end
end
