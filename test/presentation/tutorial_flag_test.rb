# frozen_string_literal: true

require_relative "presentation_helper"

class TutorialFlagTest < Minitest::Test
  include PresentationTest

  def setup
    @store = DotPopper::BestScore::Memory.new
  end

  def test_it_is_due_once_on_a_fresh_install_and_remembered_across_sessions
    flag = TutorialFlag.new(@store)
    assert flag.due?(played: false)

    flag.seen!
    refute flag.due?(played: false)
    refute TutorialFlag.new(@store).due?(played: false)
    assert_equal "seen", @store.read
  end

  def test_a_player_who_has_played_before_never_sees_it
    refute TutorialFlag.new(@store).due?(played: true)
  end

  def test_a_damaged_flag_counts_as_unseen
    @store.write("maybe")

    assert TutorialFlag.new(@store).due?(played: false)
  end

  def test_forced_it_shows_on_every_play_and_skipped_never
    @store.write("seen")

    assert TutorialFlag.new(@store, mode: :forced).due?(played: true)
    refute TutorialFlag.new(DotPopper::BestScore::Memory.new, mode: :skipped).due?(played: false)
  end

  def test_the_environment_chooses_the_mode
    assert_equal :usual, TutorialFlag.mode({})
    assert_equal :forced, TutorialFlag.mode("DOT_POPPER_TUTORIAL" => "1")
    assert_equal :forced, TutorialFlag.mode("DOT_POPPER_TUTORIAL" => "1", "DOT_POPPER_SCENARIO" => "tutorial")
    %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_TUTORIAL].each do |name|
      assert_equal :skipped, TutorialFlag.mode(name => "1"), name
    end
  end
end
