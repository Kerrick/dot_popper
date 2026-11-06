# frozen_string_literal: true

require_relative "presentation_helper"

class ScreenReportTest < Minitest::Test
  ScreenReport = DotPopper::Presentation::ScreenReport

  def test_it_says_the_window_in_one_line
    report = ScreenReport.new(units: [812, 375], pixels: [2436, 1125], dpi_scale: 3.0, native: 3.0,
                              safe: [47, 0, 718, 354],
                              mode: [812, 375, { fullscreen: true, fullscreentype: :desktop, usedpiscale: true }])

    assert_equal "screen 812x375 units, 2436x1125 pixels, dpi scale 3.0 (native 3.0), safe area 47,0,718,354, " \
                 "mode 812x375 fullscreen desktop, usedpiscale true", report.to_s
  end

  def test_a_window_says_so_and_a_scale_keeps_its_places
    report = ScreenReport.new(units: [1200, 800], pixels: [2400, 1600], dpi_scale: 2.88, native: 2.0,
                              safe: [0, 0, 1200, 800], mode: [1200, 800, { fullscreen: false }])

    assert_equal "screen 1200x800 units, 2400x1600 pixels, dpi scale 2.88 (native 2.0), safe area 0,0,1200,800, " \
                 "mode 1200x800 windowed", report.to_s
  end
end
