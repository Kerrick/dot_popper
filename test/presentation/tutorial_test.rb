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
    assert_equal 1, @effects.take_sprays.size, "it bursts at once"
    assert bright.fresh?, "still bright as its numbers fly out of it"
    assert_nil next_dot, "and nothing is born under it yet"
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

    assert bright.fresh?, "the stopped clock holds it at its pop's instant"
    play_for(SCRIPT.hold + STEP)
    assert_equal :peek, @tutorial.beat
    assert bright.popped?, "as time flows, it shows it is popped"
    following = next_dot
    assert following.fresh?
    assert_equal bright.id, @tutorial.dots.top_at(following.x, following.y).id, "and one is born under it"
    play_for(SCRIPT.resume / 2)
    assert_operator @tutorial.rate, :>, 0.0, "then it runs on by itself"
  end

  def test_as_the_bright_dot_peeks_out_the_guide_taps_the_popped_one_and_its_cost_plays
    to_the_peek
    assert_equal :warn, @tutorial.beat
    assert_equal Anchor.dot(Tutorial::BRIGHT), @tutorial.spotlight.to
    play_for(SCRIPT.stop)
    assert_in_delta 0.0, @tutorial.rate
    assert_operator Math.hypot(bright.x - next_dot.x, bright.y - next_dot.y), :<, 2 * R, "it has only peeked out"
    assert_empty @tutorial.flights

    pressed = nil
    play_until do
      pose = @tutorial.ghost_pose
      pressed ||= pose if pose&.press == 1.0
      @tutorial.flights.any?
    end
    assert pressed && near?(pressed, bright), "the guide presses the popped dot"
    assert_equal %w[−1 −2], @tutorial.flights.map(&:text), "and its cost leaps out of the score and the time"
    assert_equal [nil, :stopwatch], @tutorial.flights.map(&:icon)
    assert_equal [0, 9], shown, "which drop by it, the score no lower than 0, as in play"
    assert_equal :bonk, @sounds.names.last
    assert_equal 1, @effects.reveals.size, "the bright dot under it is outlined"
    assert_equal 1, @effects.rings.count { it.look == Look::ALARM_RING }
    assert_operator @tutorial.animations.pose(bright, @tutorial.now + 0.05).alarm, :>, 0.0, "it shudders"
    assert_equal [Look::HAPTICS.pop], @haptics.buzzes, "only the player's own taps buzz"
    assert_in_delta 0.0, @effects.shake_x

    poses = 40.times.map do
      play_for(STEP * 2)
      @tutorial.ghost_pose
    end
    assert(poses.last(20).all? { it.press.zero? }, "then it lifts, and taps no more")
    assert(poses.last.then { !near?(it, bright) && !near?(it, next_dot) }, "and waits to one side")
    assert_equal 1, @effects.reveals.size, "once"

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
    end, "the guide moves to the clear bright dot and taps it")
  end

  # The maintainer: the guide "lingered there just a little too long", and
  # "should wiggle a left-and-right 'no' instead of just hover-bobbing".
  # It wags once it reaches its place, settles, and goes on to the bright
  # dot soon after, with no idle wait.
  def test_after_the_cost_the_guide_wags_its_finger_no_then_goes_on_soon
    to_the_peek
    started = @tutorial.now
    turns = []
    play_until(within: 900) do
      turns << [@tutorial.now - started, @tutorial.ghost_pose&.turn.to_f]
      @tutorial.beat == :aim_next
    end
    wag = SCRIPT.ghost.wag
    arrives = (GhostHand::LIFTED * SCRIPT.ghost.loop) + SCRIPT.ghost.glide
    wagging = turns.select { |at, _| at.between?(arrives, arrives + wag.time) }.map(&:last)

    assert_operator wagging.max, :>, wag.angle * 0.8, "it wags one way"
    assert_operator wagging.min, :<, -wag.angle * 0.8, "and the other"
    assert_operator wagging.each_cons(2).count { |a, b| a.negative? != b.negative? }, :>=, 3, "back and forth"
    assert(turns.select { |at, _| at < arrives || at > arrives + wag.time }.all? { |_, turn| turn.abs < 1e-9 })
    waited = @tutorial.now - started
    assert_operator waited, :>=, arrives + SCRIPT.ghost.waiting, "only once it has wagged and settled"
    assert_operator waited, :<, arrives + SCRIPT.ghost.waiting + 0.4, "and soon after"
  end

  def test_a_calm_guide_wags_gentler
    calm = Tutorial.new(field: @field, center: [600.0, 400.0], effects: @effects, sounds: @sounds, haptics: @haptics,
                        look: Look, calm: true)
    assert_equal Look::CALM_WAG, calm.ghost.look.wag
    assert_operator Look::CALM_WAG.angle, :<, SCRIPT.ghost.wag.angle
  end

  # On an upright phone the first dot freezes near a side wall, where the
  # new bright dot, going back across, would meet it and slide along
  # beside the popped one, never clear. There they part up and down, the
  # new one going down, away from where the guide waits.
  def test_near_a_side_wall_the_dots_part_up_and_down
    field = DotPopper::Field.new(400, 850, R)
    @tutorial = Tutorial.new(field:, center: [200.0, 425.0], effects: Effects.new(radius: R), sounds: @sounds,
                             haptics: @haptics, look: Look)
    to_the_peek
    play_until(within: 900) { @tutorial.beat == :aim_next }

    assert_operator next_dot.y, :>, bright.y + (SCRIPT.clear * R * 0.9), "it slid out below"
    assert_operator @tutorial.now, :<, 7.0, "with no long wait"
  end

  def test_a_tap_on_the_popped_dot_costs_what_it_does_in_play_and_the_beat_goes_on
    to_the_peek
    tap_on(bright)

    assert_equal :warn, @tutorial.beat, "the beat goes on"
    assert_equal [0, 9], shown, "two seconds, and the one point there was to lose"
    assert_equal %w[−1 −2], @tutorial.flights.map(&:text), "it says only what was lost"
    assert_equal [Anchor.hud(:score), Anchor.hud(:time)], @tutorial.flights.map(&:from)
    assert_equal :bonk, @sounds.names.last
    assert_equal Look::HAPTICS.penalty, @haptics.buzzes.last, "the player's own tap buzzes"
    assert_equal 1, @effects.reveals.size, "the bright dot under it is outlined"
    assert_in_delta 0.0, @effects.shake_x
    assert_in_delta 0.0, @effects.shake_y
  end

  def test_the_last_pop_spawns_a_dot_under_them_all_and_hands_the_scene_over_as_it_is
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)

    assert_equal :runs, @tutorial.beat
    assert next_dot.fresh?, "it bursts still bright"
    play_for(SCRIPT.gap + SCRIPT.quick + STEP)
    assert_equal [1, 10], shown, "two pops, less what the guide's tap cost"
    assert_equal [Tutorial::BRIGHT, Tutorial::NEXT], @tutorial.dots.map(&:id), "nothing is born while time stands"
    play_for(SCRIPT.linger)
    assert_equal :ending, @tutorial.beat
    assert_equal [Tutorial::BRIGHT, Tutorial::NEXT, Tutorial::LAST], @tutorial.dots.map(&:id)
    assert_equal [true, true, false], @tutorial.dots.map(&:popped?), "as it flows, a bright dot goes in under them all"
    last = @tutorial.dots.to_a.last
    assert_includes DotPopper::Rules::SPEEDS.map { it * R }, last.velocity_x.abs, "at one of the game's speeds"
    still = last
    now = @tutorial.dots.to_a.last
    assert_operator Math.hypot(now.x - still.x, now.y - still.y), :<, 0.1, "time held still till then"
    assert_equal Anchor.hud(:time), @tutorial.spotlight.to, "the light moves to the clock"
    play_for(SCRIPT.handover + STEP)
    assert @tutorial.over?
    assert_in_delta 1.0, @tutorial.rate, 1e-9, "and time flows as the game's does"
    assert_equal [1, 10], [@tutorial.score, @tutorial.seconds], "what it leaves the round"
    assert_equal 3, @tutorial.dots.size, "no dot fades or is added"
  end

  # However often the player taps the popped dot, the score and the
  # clock stop at 0, as Countdown and the score's floor do in play, and
  # say nothing more once they are there; the clock is still, so it never
  # runs out, and the last pop's second is what the round starts with.
  def test_wrong_taps_stop_at_nothing_and_the_round_gets_what_is_left
    to_the_peek
    7.times { tap_on(bright) }

    assert_equal [0, 0], shown
    assert_equal %w[−1 −2 −2 −2 −2 −2 −1], @tutorial.flights.map(&:text), "what was left, then nothing"
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)
    play_until(within: 900) { @tutorial.over? }
    assert_equal [1, 1], [@tutorial.score, @tutorial.seconds]
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
    play_until { @tutorial.beat == :peek }
    following = next_dot
    x = following.x - (following.radius * 0.9)
    @tutorial.tap(x, following.y)

    assert_equal :peek, @tutorial.beat
    assert next_dot.fresh?
  end

  def test_the_bursting_dot_takes_no_second_tap_while_its_numbers_fly
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    tap_on(bright)

    assert_equal %i[pop], @sounds.names
    play_until { @tutorial.beat == :peek }
    assert_equal [1, 11], shown, "one pop, one point and one second"
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
