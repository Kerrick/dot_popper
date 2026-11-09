# frozen_string_literal: true

require_relative "presentation_helper"

class ScrimTest < Minitest::Test
  include PresentationTest

  # Drawn one inside the other, the layers cover the middle with all of
  # them, which comes to the backing's own opacity.
  def test_the_layers_add_up_to_its_opacity_in_the_middle
    style = ScrimStyle.new(alpha: 0.6, feather: 40, layers: 10, pad: 18)
    covered = 1 - ((1 - style.layer_alpha)**style.layers)

    assert_in_delta 0.6, covered, 1e-9
    assert_operator style.layer_alpha, :<, 0.1, "its edge is faint"
  end

  def test_the_layers_step_in_evenly_across_the_feather
    style = ScrimStyle.new(alpha: 0.6, feather: 40, layers: 4, pad: 18)

    assert_equal [0.0, 10.0, 20.0, 30.0], style.insets(40)
  end

  def test_game_overs_backing_never_hides_the_pile
    assert_includes 0.55..0.65, Style::GAME_OVER_BACKING.alpha
  end
end
