# frozen_string_literal: true

require_relative "presentation_helper"

class HudTest < Minitest::Test
  include PresentationTest

  def setup
    @round = round_with(dot(100, 100))
    @hud = Hud.blank(Look::HUD, Look::WORDS).read(@round, 0.0)
  end

  def test_it_shows_the_score_and_the_whole_seconds_left
    assert_equal %w[0 10], [@hud.score_readout.text, @hud.time_readout.text]
    assert_equal %w[SCORE TIME], [@hud.score_readout.label, @hud.time_readout.label]
  end

  def test_a_number_bumps_when_it_changes_and_settles
    score!(@round, 1)
    hud = @hud.read(@round, 1.0)

    assert_operator hud.score_readout.scale, :>, 1.2
    assert_in_delta 1.0, hud.read(@round, 2.0).score_readout.scale
  end

  def test_the_clock_ticks_on_each_of_its_last_seconds
    ticks = []
    hud = @hud
    (1..100).each do |step|
      @round.update(0.1)
      hud = hud.read(@round, step * 0.1) { ticks << it }
    end

    assert_equal [3, 2, 1], ticks
    assert hud.urgent?
    assert_equal "0", hud.time_readout.text
  end

  def test_the_clock_is_calm_until_its_last_seconds
    refute @hud.urgent?
    assert_in_delta 0.0, @hud.time_readout.urgency
  end
end
