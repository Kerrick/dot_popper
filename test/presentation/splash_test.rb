# frozen_string_literal: true

require_relative "presentation_helper"

class SplashTest < Minitest::Test
  include PresentationTest

  def test_muted_it_fades_in_holds_and_fades_out_in_about_one_and_a_half_seconds
    assert_in_delta 1.4, Splash.start.total, 0.05
    splash = Splash.start
    assert_equal [0.0, 1.0], [splash.mark, splash.ground]
    assert_in_delta 0.5, splash.advance(Splash::FADE_IN / 2).mark, 1e-9
    held = splash.advance(Splash::FADE_IN + 0.3)
    assert_equal [1.0, 1.0], [held.mark, held.ground]
    middle = splash.advance(Splash.start.total - (Splash::FADE_OUT / 2))
    assert_in_delta 0.5, middle.mark, 1e-9
    assert_in_delta 0.5, middle.ground, 1e-9
  end

  def test_it_is_over_after_its_total_time_and_a_skip_ends_it
    refute_predicate Splash.start.advance(Splash.start.total - 0.01), :over?
    assert_predicate Splash.start.advance(Splash.start.total), :over?
    assert_predicate Splash.start.skip, :over?
    assert_equal 0.0, Splash.start.skip.mark
  end

  def test_the_bot_the_director_and_a_request_leave_it_out
    refute Splash.skipped?({})
    refute Splash.skipped?("DOT_POPPER_NO_SPLASH" => "")
    %w[DOT_POPPER_AUTOPLAY DOT_POPPER_SCENARIO DOT_POPPER_NO_SPLASH].each { assert Splash.skipped?({ it => "1" }) }
  end

  def test_the_logotype_is_centred_and_keeps_setdefs_proportions
    mark = Logotype.new(size: 100)
    left = mark.left(600)
    assert_in_delta 600, left + (mark.width / 2.0), 1e-9
    assert_equal %w[s e t d e f], mark.letters(left).map(&:first)
    block_left, block_width = mark.block(left)
    assert_in_delta 1.03 / 1.78, block_width / mark.block_height, 1e-9
    assert_operator block_left, :>, mark.letters(left).last.last
    baseline = mark.baseline(400)
    assert_in_delta 400, mark.block_top(baseline) + (mark.block_height / 2.0), 1e-9
    assert_in_delta 1.57 * 0.52 * 100, baseline - mark.block_top(baseline), 1e-9
  end

  def test_it_is_sized_in_whole_units_to_the_window_and_fits_a_phone
    wide = Logotype.fit(1200, 800)
    assert_kind_of Integer, wide.size
    assert_in_delta 0.78, wide.width / 1200, 0.01
    assert_operator Logotype.fit(400, 850).width, :<=, 400 * 0.7
    assert_operator Logotype.fit(1200, 300).block_height, :<=, 300 * 0.6
  end

  # The maintainer's jingle: Bigger, Smaller, Bigger, Smaller, "Your
  # records", Back, at 120 beats a minute, in quarter, quarter, a quarter's
  # rest, eighth, eighth, quarter, quarter.
  def test_the_jingle_starts_its_clicks_on_the_beat
    starts = Splash::JINGLE.map(&:at)

    [0.0, 0.5, 1.5, 1.75, 2.0, 2.5].zip(starts).each { |want, got| assert_in_delta want, got, 1e-9 }
    assert_equal [1.2, 0.9, 1.2, 0.9, 1.0, 0.8], Splash::JINGLE.map(&:pitch), "high, low, high, low, middle, lower"
  end

  def test_each_click_sounds_once_whatever_the_frames
    [1 / 60.0, 1 / 144.0, 0.1].each do |frame|
      splash = Splash.start(sounding: true)
      heard = []
      until splash.over?
        heard.concat(splash.notes(frame))
        splash = splash.advance(frame)
      end

      assert_equal Splash::JINGLE, heard
    end
  end

  # The maintainer: the splash lengthens only when it plays the jingle.
  def test_with_sound_it_lasts_until_the_last_click_has_rung_and_muted_it_is_short_and_silent
    assert_operator Splash.start(sounding: true).total, :>, Splash::JINGLE.last.at
    assert_in_delta 1.4, Splash.start(sounding: false).total, 0.05
    assert_empty Splash.start(sounding: false).notes(10.0)
    assert_empty Splash.start(sounding: true).advance(0.7).skip.notes(1.0), "a press silences the rest"
  end

  # The maintainer's idea: the block blinks like an amber terminal's
  # cursor, with the jingle's notes, or steadily on the beat, to compare.
  def test_with_the_notes_each_note_flips_the_block_and_the_last_leaves_it_dark
    splash = Splash.start(sounding: true)
    Splash::JINGLE.each_slice(2) do |on, off|
      assert_in_delta 1.0, splash.with(at: on.at + Splash::LIGHTS).block, 1e-9, "lit just after #{on.at}"
      assert_in_delta 1.0, splash.with(at: off.at - 0.01).block, 1e-9, "still lit just before #{off.at}"
      assert_in_delta 0.0, splash.with(at: off.at + Splash::FADES).block, 1e-9, "dark once #{off.at} has faded"
    end
    Splash::JINGLE.each_slice(2).each_cons(2) do |(_, off), (on, _)|
      assert_in_delta 0.0, splash.with(at: on.at - 0.01).block, 1e-9, "dark just before #{on.at}"
      assert_in_delta 1.0, splash.with(at: on.at + Splash::LIGHTS).block, 1e-9
    end
    assert_in_delta 0.0, splash.with(at: Splash::SOUNDING).block, 1e-9, "dark after the last note"
    assert_in_delta 0.5, splash.with(at: Splash::LIGHTS / 2).block, 1e-9
  end

  def test_on_the_beat_and_muted_it_is_lit_for_a_beat_and_dark_for_the_next
    [Splash.start(sounding: true, blink: :beat), Splash.start].each do |splash|
      [0, 2].each do |start|
        lit = start * Splash::BEAT
        assert_in_delta 1.0, splash.with(at: lit + Splash::LIGHTS).block, 1e-9
        assert_in_delta 1.0, splash.with(at: lit + Splash::BEAT - 0.01).block, 1e-9, "lit the whole beat"
        assert_in_delta 0.5, splash.with(at: lit + Splash::BEAT + (Splash::FADES / 2)).block, 1e-9
        assert_in_delta 0.0, splash.with(at: lit + Splash::BEAT + Splash::FADES).block, 1e-9
        assert_in_delta 0.0, splash.with(at: lit + (2 * Splash::BEAT) - 0.01).block, 1e-9, "dark the whole next beat"
      end
    end
  end

  def test_the_shortest_dark_span_outlasts_the_fade
    gaps = Splash::JINGLE.each_slice(2).each_cons(2).map { |(_, off), (on, _)| on.at - off.at }
    assert_operator gaps.min, :>, Splash::FADES
  end

  def test_the_environment_chooses_the_blink
    assert_equal :notes, Splash.blink({})
    assert_equal :beat, Splash.blink("DOT_POPPER_SPLASH_BLINK" => "beat")
    assert_equal :notes, Splash.blink("DOT_POPPER_SPLASH_BLINK" => "disco")
  end
end
