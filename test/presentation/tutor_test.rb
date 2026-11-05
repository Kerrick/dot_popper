# frozen_string_literal: true

require_relative "presentation_helper"

class TutorTest < Minitest::Test
  include PresentationTest

  def test_it_teaches_once_and_remembers_across_sessions
    store = DotPopper::BestScore::Memory.new
    tutor = Tutor.new(store)

    assert_equal Look::WORDS.covered, tutor.slipped(Look::WORDS.covered, Look::HINT, 0.0).lines
    assert_nil tutor.slipped(Look::WORDS.covered, Look::HINT, 1.0)
    assert Tutor.new(store).taught?
  end

  def test_a_hint_fades_in_stays_and_goes
    hint = Hint.new(lines: ["Hi."], look: Look::HINT, at: 1.0)

    assert_in_delta 0.0, hint.alpha(1.0)
    assert_in_delta 1.0, hint.alpha(2.0)
    assert_operator hint.alpha(1.0 + Look::HINT.life - 0.1), :<, 0.5
    refute hint.alive?(1.0 + Look::HINT.life)
  end
end
