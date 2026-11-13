# frozen_string_literal: true

require_relative "presentation_helper"

class SceneryTest < Minitest::Test
  include PresentationTest

  INK = Color.hex("#000000")

  def triangle_area((a, b, c)) = (((b[0] - a[0]) * (c[1] - a[1])) - ((b[1] - a[1]) * (c[0] - a[0]))).abs / 2.0

  def test_any_simple_outline_is_cut_into_triangles_that_cover_it
    # An L, which is not a fan about any one of its corners.
    outline = [[0, 0], [10, 0], [10, 2], [2, 2], [2, 10], [0, 10]]
    out = []
    Scenery.poly(out, INK, outline)

    assert_equal 4, out.size
    assert(out.all? { it.points.size == 3 })
    assert_in_delta 36.0, out.sum { triangle_area(it.points) }
  end

  def test_an_outline_drawn_either_way_round_is_cut_alike
    outline = [[0, 0], [10, 0], [10, 2], [2, 2], [2, 10], [0, 10]].reverse
    out = []
    Scenery.poly(out, INK, outline)

    assert_in_delta 36.0, out.sum { triangle_area(it.points) }
  end

  def test_every_scene_draws_on_a_phone_and_a_desktop
    Style::THEMES.filter_map { it.art&.scenery }.each do |kind|
      [[400, 850], [1200, 800]].each do |width, height|
        shapes = Scenery.for(kind, width, height)

        refute_empty shapes, "#{kind} at #{width}x#{height}"
        assert(shapes.all? { it.is_a?(Scenery::Dot) || it.points.flatten.all?(&:finite?) }, "#{kind} at #{width}x#{height}")
      end
    end
  end
end
