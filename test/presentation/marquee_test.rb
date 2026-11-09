# frozen_string_literal: true

require_relative "presentation_helper"

class MarqueeTest < Minitest::Test
  include PresentationTest

  # The prompt breathes, but at its faintest it stays easy to read.
  def test_the_prompt_breathes_between_its_faintest_and_full
    marquee = Marquee.new(style: Style::TITLE, score_record: 0, at: 0.0)
    breath = Style::TITLE.breath

    assert_in_delta Style::TITLE.faintest, marquee.prompt(0.0)
    assert_in_delta 1.0, marquee.prompt(breath / 2.0)
    assert_operator Style::TITLE.faintest, :>=, 0.75
  end
end
