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

  def test_it_shows_the_streak_toward_a_bonus_dot_as_dots_and_bumps_the_newest
    readout = @hud.streak_readout

    assert_equal [0, DotPopper::Rules::BONUS.streak, false], [readout.lit, readout.size, readout.ready]
    @round.instance_variable_set(:@streak, 3)
    hud = @hud.read(@round, 1.0)

    assert_equal 3, hud.streak_readout.lit
    assert hud.streak_readout.lit?(2)
    refute hud.streak_readout.lit?(3)
    assert hud.streak_readout.bumping?(2)
    assert_operator hud.streak_readout.scale, :>, 1.2
    assert_in_delta 1.0, hud.read(@round, 2.0).streak_readout.scale
  end

  def test_a_wrong_tap_empties_the_streak_without_a_bump
    @round.instance_variable_set(:@streak, 5)
    hud = @hud.read(@round, 1.0)
    @round.instance_variable_set(:@streak, 0)
    after = hud.read(@round, 5.0)

    assert_equal 0, after.streak_readout.lit
    assert_in_delta 1.0, after.streak_readout.scale
  end

  def test_with_a_bonus_dot_on_the_field_every_dot_of_the_streak_is_lit
    round = round_with(dot(100, 100, bonus: true))
    readout = @hud.read(round, 0.0).streak_readout

    assert readout.ready
    assert(Array.new(readout.size) { readout.lit?(it) }.all?)
  end

  def test_there_is_no_streak_without_a_bonus_rule_or_after_the_round
    plain = DotPopper::Round.new(field, random: Random.new(1), bonus: nil)

    assert_nil @hud.read(plain, 0.0).streak_readout
    @round.update(60)
    assert_nil @hud.read(@round, 60.0).streak_readout
  end
end
