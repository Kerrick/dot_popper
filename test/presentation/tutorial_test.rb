# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "screen_plans_test"

class TutorialTest < Minitest::Test
  include PresentationTest

  STEP = 1 / 60.0
  SCRIPT = Look::TUTORIAL

  def setup
    @sounds = FakeSounds.new
    @haptics = FakeHaptics.new
    @effects = Effects.new(radius: R)
    @field = DotPopper::Field.new(1200, 800, R)
    @tutorial = Tutorial.new(field: @field, center: [600.0, 400.0], effects: @effects, sounds: @sounds,
                             haptics: @haptics, look: Look)
  end

  def test_the_bright_dot_drifts_at_the_slowest_speed_then_time_eases_to_a_stop
    dot = bright
    speed = DotPopper::Rules::SPEEDS.min * R
    assert_equal [-speed, speed], [dot.velocity_x, dot.velocity_y]
    assert_equal :drift, @tutorial.beat

    play_for(SCRIPT.drift + STEP)
    assert_equal :aim, @tutorial.beat
    play_for(SCRIPT.stop / 2)
    assert @tutorial.rate.between?(0.05, 0.95), "time eases, never snaps (#{@tutorial.rate})"
    play_for(SCRIPT.stop)
    assert_in_delta 0.0, @tutorial.rate
    still = bright
    play_for(3.0)
    assert_equal [still.x, still.y], [bright.x, bright.y], "time stands still until the player taps"
  end

  def test_the_bright_dot_freezes_well_away_from_the_middle_where_a_gamepad_cursor_starts
    sizes = ScreenPlansTest::SIZES
    sizes.each do |width, height|
      radius = DotPopper::DotSize.fitted(width, height).radius
      field = DotPopper::Field.new(width, height, radius)
      inset = Rect.new(x: 0.0, y: 44.0, width: width.to_f, height: height - 78.0)
      screen = Layout.new(width:, height:, safe: inset, look: Look::LAYOUT)
      tutorial = Tutorial.new(field:, center: [screen.center_x, screen.center_y], effects: Effects.new(radius:),
                              sounds: @sounds, haptics: @haptics, look: Look)
      (((SCRIPT.drift + SCRIPT.stop + 0.2) / STEP).ceil).times { tutorial.update(STEP) }
      dot = tutorial.dots.find { it.id == Tutorial::BRIGHT }
      name = "#{width}x#{height}"

      assert_equal :aim, tutorial.beat, name
      assert_operator Math.hypot(dot.x - screen.center_x, dot.y - screen.center_y), :>=, 3 * radius, name
      assert_operator dot.x - radius, :>=, inset.x, name
      assert_operator dot.x + radius, :<=, inset.right, name
      assert_operator dot.y - radius, :>=, inset.y + screen.margin, name
      assert_operator dot.y + radius, :<=, inset.bottom, name
      assert_operator dot.x + radius, :<=, screen.skip_button.x, "#{name}: clear of the skip button" \
        if dot.y - radius < screen.skip_button.bottom
    end
  end

  def test_the_spotlight_finds_the_bright_dot_and_the_ghost_hand_taps_it
    play_for(SCRIPT.drift + 0.5)
    assert_equal Anchor.dot(Tutorial::BRIGHT), @tutorial.spotlight.to
    assert_operator @tutorial.spotlight.darkness(@tutorial.now), :>, 0.5
    poses = (0..100).map do
      play_for(STEP * 2)
      @tutorial.ghost_pose
    end
    assert(poses.any? { it.press == 1.0 && near?(it, bright) }, "the hand presses on the dot")
    assert(poses.any?(&:since_press), "the press is marked, for its ring")
    assert(poses.any? { it.press.zero? }, "and lifts again")
  end

  def test_popping_the_bright_dot_flies_a_point_and_a_second_into_the_hud
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)

    assert_equal :points, @tutorial.beat
    assert_equal %i[pop], @sounds.names
    assert_equal [Look::HAPTICS.pop], @haptics.buzzes
    assert bright.popped?
    following = next_dot
    assert following.fresh?
    assert_equal bright.id, @tutorial.dots.top_at(following.x, following.y).id, "it is born under the popped dot"
    assert_equal [0, 10], shown

    play_for(SCRIPT.gap + (SCRIPT.flight / 2))
    flight = @tutorial.flights.first
    assert_equal ["+1", Anchor.hud(:score)], [flight.text, flight.to]
    assert_equal Anchor.hud(:score), @tutorial.spotlight.to
    play_for(SCRIPT.flight)
    assert_equal [1, 10], shown, "the score counts the point as it lands"
    assert_equal %i[pop tick], @sounds.names
    play_for(SCRIPT.gap + SCRIPT.flight)
    assert_equal [1, 11], shown, "and the time its second"
    assert_equal Anchor.hud(:time), @tutorial.spotlight.to
    assert_in_delta 0.0, @tutorial.rate, 1e-9, "time holds still meanwhile"

    play_for(SCRIPT.hold + STEP)
    assert_equal :peek, @tutorial.beat
    play_for(SCRIPT.resume / 2)
    assert_operator @tutorial.rate, :>, 0.0, "then it runs on by itself"
  end

  def test_time_stops_as_the_bright_dot_peeks_out_and_the_hand_holds_back_from_the_popped_one
    to_the_peek
    assert_equal :warn, @tutorial.beat
    assert_equal Anchor.dot(Tutorial::BRIGHT), @tutorial.spotlight.to
    play_for(SCRIPT.cross + SCRIPT.stop)
    assert_in_delta 0.0, @tutorial.rate
    assert_in_delta 1.0, @tutorial.cross
    assert_equal Tutorial::BRIGHT, @tutorial.crossed.id
    assert_operator Math.hypot(bright.x - next_dot.x, bright.y - next_dot.y), :<, 2 * R, "it has only peeked out"
    poses = 30.times.map do
      play_for(STEP * 2)
      @tutorial.ghost_pose
    end
    assert(poses.all? { it.press.zero? }, "the hand never taps the popped dot")
    assert(poses.last.then { near?(it, bright) }, "it hovers over it")

    play_until { @tutorial.beat == :slide }
    play_for(SCRIPT.resume)
    assert_in_delta SCRIPT.slow, @tutorial.rate, 1e-9, "time flows again, slowly"
    play_until { @tutorial.beat == :aim_next }
    assert_operator Math.hypot(bright.x - next_dot.x, bright.y - next_dot.y), :>=, SCRIPT.clear * R
    play_for(1.0)
    assert_in_delta 0.0, @tutorial.rate
    assert(48.times.any? do
      play_for(STEP * 2)
      pose = @tutorial.ghost_pose
      pose.press == 1.0 && near?(pose, next_dot)
    end, "the hand moves to the clear bright dot and taps it")
  end

  def test_a_tap_on_the_popped_dot_shows_its_cost_and_the_beat_goes_on
    to_the_peek
    tap_on(bright)

    assert_equal :warn, @tutorial.beat, "the beat goes on"
    assert_equal [0, 9], shown, "the score and time drop, the score no lower than 0"
    assert_equal %w[−2 −2], @tutorial.flights.map(&:text)
    assert_equal [Anchor.hud(:score), Anchor.hud(:time)], @tutorial.flights.map(&:from)
    assert_equal [nil, :stopwatch], @tutorial.flights.map(&:icon)
    assert_equal :bonk, @sounds.names.last
    assert_equal 1, @effects.reveals.size, "the bright dot under it is outlined"
    assert_equal 1, @effects.rings.count { it.look == Look::ALARM_RING }
    assert_in_delta 0.0, @effects.shake_x
    assert_in_delta 0.0, @effects.shake_y
  end

  def test_the_last_pop_flies_in_then_the_scene_clears_for_the_round
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)

    assert_equal :runs, @tutorial.beat
    assert_equal 2, @tutorial.dots.count(&:popped?)
    play_for(SCRIPT.gap + SCRIPT.quick + STEP)
    assert_equal [2, 12], shown
    play_for(SCRIPT.linger)
    assert_equal :ending, @tutorial.beat
    assert_equal [0, 10], shown, "the HUD shows the round's start"
    assert_equal Anchor.hud(:time), @tutorial.spotlight.to
    play_for(SCRIPT.dissolve)
    assert @tutorial.over?
    assert_in_delta 0.0, @tutorial.opacity
  end

  def test_a_tap_on_empty_space_only_ripples
    play_for(SCRIPT.drift + 0.5)
    @tutorial.tap(5, 795)

    assert_equal :aim, @tutorial.beat
    assert_equal [Look::TOUCH_RIPPLE], @effects.rings.map(&:look).last(1)
    assert_empty @sounds.names
  end

  def test_the_next_dot_waits_for_its_beat
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    following = next_dot
    x = following.x - (following.radius * 0.9)
    @tutorial.tap(x, following.y)

    assert_equal :points, @tutorial.beat
    assert next_dot.fresh?
  end

  def test_a_resized_window_keeps_the_dots_on_it
    @tutorial.refit(DotPopper::Field.new(400, 850, R))

    assert bright.x.between?(R, 400 - R)
    assert_equal 400, @tutorial.field.width
  end

  private

  def bright = @tutorial.dots.find { it.id == Tutorial::BRIGHT }
  def next_dot = @tutorial.dots.find { it.id == Tutorial::NEXT }
  def shown = [@tutorial.hud.score, @tutorial.hud.seconds]
  def tap_on(dot) = @tutorial.tap(dot.x, dot.y)
  def near?(pose, dot) = Math.hypot(pose.x - dot.x, pose.y - dot.y) < R

  def play_for(seconds)
    (seconds / STEP).ceil.times { @tutorial.update(STEP) }
  end

  def play_until(within: 600)
    within.times do
      return if yield

      @tutorial.update(STEP)
    end
    flunk "never got there"
  end

  def to_the_peek
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    play_until { @tutorial.beat == :warn }
  end
end
