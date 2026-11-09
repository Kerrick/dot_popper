# frozen_string_literal: true

require_relative "presentation_helper"

class HudTest < Minitest::Test
  include PresentationTest

  def setup
    @game = game_with(dot(100, 100))
    @hud = Hud.blank(Style::HUD, Style::WORDS).read(@game, 0.0)
  end

  def test_it_shows_the_score_and_the_whole_seconds_left
    assert_equal %w[0 10], [@hud.score_readout.text, @hud.time_readout.text]
    assert_equal %w[SCORE TIME], [@hud.score_readout.label, @hud.time_readout.label]
  end

  def test_a_number_bumps_when_it_changes_and_settles
    score!(@game, 1)
    hud = @hud.read(@game, 1.0)

    assert_operator hud.score_readout.scale, :>, 1.2
    assert_in_delta 1.0, hud.read(@game, 2.0).score_readout.scale
  end

  def test_the_clock_ticks_on_each_of_its_last_seconds
    ticks = []
    hud = @hud
    (1..100).each do |step|
      @game.update(0.1)
      hud = hud.read(@game, step * 0.1) { ticks << it }
    end

    assert_equal [3, 2, 1], ticks
    assert hud.urgent?
    assert_equal "0", hud.time_readout.text
  end

  def test_the_clock_is_calm_until_its_last_seconds
    refute @hud.urgent?
    assert_in_delta 0.0, @hud.time_readout.urgency
  end

  def test_it_shows_the_dots_in_a_row_toward_a_bonus_dot_as_dots_and_bumps_the_newest
    readout = @hud.dots_in_a_row_readout

    assert_equal [0, DotPopper::Rules::BONUS.dots_in_a_row, false], [readout.lit, readout.size, readout.ready]
    @game.instance_variable_set(:@dots_in_a_row, 3)
    hud = @hud.read(@game, 1.0)

    assert_equal 3, hud.dots_in_a_row_readout.lit
    assert hud.dots_in_a_row_readout.lit?(2)
    refute hud.dots_in_a_row_readout.lit?(3)
    assert hud.dots_in_a_row_readout.bumping?(2)
    assert_operator hud.dots_in_a_row_readout.scale, :>, 1.2
    assert_in_delta 1.0, hud.read(@game, 2.0).dots_in_a_row_readout.scale
  end

  def test_a_wrong_tap_empties_the_dots_in_a_row_without_a_bump
    @game.instance_variable_set(:@dots_in_a_row, 5)
    hud = @hud.read(@game, 1.0)
    @game.instance_variable_set(:@dots_in_a_row, 0)
    after = hud.read(@game, 5.0)

    assert_equal 0, after.dots_in_a_row_readout.lit
    assert_in_delta 1.0, after.dots_in_a_row_readout.scale
  end

  def test_with_a_bonus_dot_on_the_field_every_dot_of_the_dots_in_a_row_is_lit
    game = game_with(dot(100, 100, bonus: true))
    readout = @hud.read(game, 0.0).dots_in_a_row_readout

    assert readout.ready
    assert(Array.new(readout.size) { readout.lit?(it) }.all?)
  end

  def test_there_is_no_dots_in_a_row_without_a_bonus_rule_or_after_the_game
    plain = DotPopper::Game.new(field, random: Random.new(1), bonus: nil)

    assert_nil @hud.read(plain, 0.0).dots_in_a_row_readout
    @game.update(60)
    assert_nil @hud.read(@game, 60.0).dots_in_a_row_readout
  end
end
