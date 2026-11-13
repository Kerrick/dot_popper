# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "screen_plans_test"

class TutorialTest < Minitest::Test
  include PresentationTest

  STEP = 1 / 60.0
  SCRIPT = Style::TUTORIAL

  def setup
    @sounds = FakeSounds.new
    @haptics = FakeHaptics.new
    @effects = Effects.new(radius: R)
    @field = DotPopper::Field.new(1200, 800, R)
    @cabinet = DotPopper::Cabinet.new(@field)
    @tutorial = tutorial_on(@cabinet, [600.0, 400.0], effects: @effects, sounds: @sounds,
                             haptics: @haptics, style: Style)
  end

  def test_it_plays_over_a_paused_game_with_its_first_dot
    assert_instance_of DotPopper::Cabinet::Paused, @cabinet.state
    assert_equal [Tutorial::BRIGHT], @cabinet.game.dots.map(&:id)
    assert_equal @cabinet.game.dots.to_a, @tutorial.dots.to_a, "it draws the game's own dot"
    assert_same @cabinet.game.field, @tutorial.field
    assert_equal [0, 10, 0], [*shown, @tutorial.hud.dots_in_a_row], "and the HUD shows the game's numbers"
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
      radius = DotPopper::DotSize.standard(width, height).radius
      field = DotPopper::Field.new(width, height, radius)
      inset = Rect.new(x: 0.0, y: 44.0, width: width.to_f, height: height - 78.0)
      screen = Layout.new(width:, height:, safe: inset, style: Style::LAYOUT)
      tutorial = tutorial_on(DotPopper::Cabinet.new(field), [screen.center_x, screen.center_y],
                             effects: Effects.new(radius:), sounds: @sounds, haptics: @haptics, style: Style)
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
    assert_equal [Style::HAPTICS.pop], @haptics.buzzes
    assert_equal 1, @effects.take_bursts.size, "it bursts at once"
    assert bright.bright?, "still bright as its numbers fly out of it"
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
    assert_in_delta 0.0, @tutorial.rate, 1e-9, "time holds still meanwhile"

    flight = @tutorial.flights.first
    assert_equal ["+1", :dot, Anchor.hud(:dots_in_a_row)], [flight.text, flight.icon, flight.to], "a dot flies to the row"
    assert_equal Anchor.hud(:dots_in_a_row), @tutorial.spotlight.to
    assert_equal 0, @tutorial.hud.dots_in_a_row, "which counts it only as it lands"
    play_for(SCRIPT.flight)
    assert_equal 1, @tutorial.hud.dots_in_a_row

    assert bright.bright?, "the stopped clock holds it at its pop's instant"
    play_for(SCRIPT.hold)
    assert_equal :peek, @tutorial.beat
    assert bright.popped?, "as time flows, it shows it is popped"
    following = next_dot
    assert following.bright?
    assert_equal bright.id, @tutorial.dots.top_at(following.x, following.y).id, "and one is born under it"
    play_for(SCRIPT.resume / 2)
    assert_operator @tutorial.rate, :>, 0.0, "then it runs on by itself"
  end

  def test_as_the_bright_dot_peeks_out_the_guide_taps_the_popped_one_and_its_cost_games
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
    assert_equal ["−1", Anchor.at(bright.x, bright.y), Anchor.hud(:score)],
                 @tutorial.flights.first.then { [it.text, it.from, it.to] }, "its cost flies out of the dot, the score's first"
    assert_equal [1, 11], shown, "and counts only as it lands"
    assert_equal :bonk, @sounds.names.last
    assert_equal 1, @effects.reveals.size, "the bright dot under it is outlined"
    assert_equal 1, @effects.rings.count { it.style == Style::ALARM_RING }
    assert_operator @tutorial.animations.pose(bright, @tutorial.now + 0.05).alarm, :>, 0.0, "it shudders"
    assert_equal [Style::HAPTICS.pop], @haptics.buzzes, "only the player's own taps buzz"
    assert_in_delta 0.0, @effects.shake_x

    play_for(SCRIPT.flight + STEP)
    assert_equal [0, 11], shown, "the score drops as it lands"
    assert_empty @tutorial.flights, "and the next waits"
    play_for(SCRIPT.gap + (SCRIPT.flight / 2))
    assert_equal [["−2", :stopwatch, Anchor.hud(:time)]], @tutorial.flights.map { [it.text, it.icon, it.to] }
    play_for(SCRIPT.flight)
    assert_equal [0, 9], shown, "the time, in its turn"
    assert_equal 1, @tutorial.hud.dots_in_a_row
    assert_equal [["−1", :dot, Anchor.hud(:dots_in_a_row)]], @tutorial.flights.map { [it.text, it.icon, it.to] }
    play_for(SCRIPT.flight)
    assert_equal 0, @tutorial.hud.dots_in_a_row, "and the row, last"
    assert_equal :slide, @tutorial.beat
    play_for(SCRIPT.resume)
    assert_in_delta SCRIPT.slow, @tutorial.rate, 1e-9, "time flows again, slowly"

    poses = 15.times.map do
      play_for(STEP * 2)
      @tutorial.ghost_pose
    end
    assert(poses.last(10).all? { it.press.zero? }, "then it lifts, and taps no more")
    assert(poses.last.then { !near?(it, bright) && !near?(it, next_dot) }, "and waits to one side")
    assert_equal 1, @effects.reveals.size, "once"

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
    arrives = (GhostHand::PRESSED * SCRIPT.ghost.loop) + SCRIPT.gap + (2 * (SCRIPT.flight + SCRIPT.gap)) + SCRIPT.ghost.glide
    wagging = turns.select { |at, _| at.between?(arrives, arrives + wag.time) }.map(&:last)

    assert_operator wagging.max, :>, wag.angle * 0.8, "it wags one way"
    assert_operator wagging.min, :<, -wag.angle * 0.8, "and the other"
    assert_operator wagging.each_cons(2).count { |a, b| a.negative? != b.negative? }, :>=, 3, "back and forth"
    assert(turns.select { |at, _| at < arrives || at > arrives + wag.time + (2 * STEP) }.all? { |_, turn| turn.abs < 1e-9 })
    waited = @tutorial.now - started
    assert_operator waited, :>=, arrives + SCRIPT.ghost.waiting, "only once it has wagged and settled"
    assert_operator waited, :<, arrives + SCRIPT.ghost.waiting + 0.4, "and soon after"
  end

  def test_a_calm_guide_wags_gentler
    calm = tutorial_on(DotPopper::Cabinet.new(@field), [600.0, 400.0], effects: @effects,
                        sounds: @sounds, haptics: @haptics, style: Style, calm: true)
    assert_equal Style::CALM_WAG, calm.ghost.style.wag
    assert_operator Style::CALM_WAG.angle, :<, SCRIPT.ghost.wag.angle
  end

  # On an upright phone the first dot freezes near a side wall, where the
  # new bright dot, going back across, would meet it and slide along
  # beside the popped one, never clear. There they part up and down, the
  # new one going down, away from where the guide waits.
  def test_near_a_side_wall_the_dots_part_up_and_down
    @cabinet = DotPopper::Cabinet.new(DotPopper::Field.new(400, 850, R))
    @tutorial = tutorial_on(@cabinet, [200.0, 425.0], effects: Effects.new(radius: R), sounds: @sounds,
                             haptics: @haptics, style: Style)
    to_the_peek
    play_until(within: 900) { @tutorial.beat == :aim_next }

    assert_operator next_dot.y, :>, bright.y + (SCRIPT.clear * R * 0.9), "it slid out below"
    assert_operator @tutorial.now, :<, 7.6, "with no long wait"
  end

  # The maintainer: "I am still able to click the bad red dot and lose
  # time". On the player's own turn too, a tap there does nothing.
  def test_a_tap_on_the_popped_dot_never_costs_the_player
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    sounds = @sounds.names.dup
    rings = @effects.rings.size
    2.times { tap_on(bright) }

    assert_equal :aim_next, @tutorial.beat
    assert_equal [0, 9], shown
    assert_equal sounds, @sounds.names
    assert_equal rings, @effects.rings.size
    assert_equal [Style::HAPTICS.pop], @haptics.buzzes
  end

  # The maintainer: a playtester "tapped the dark dot as soon as the
  # tutorial hand did". While the hand shows or the scene plays, a tap
  # is not heard: no pop, no cost, no sound, no buzz, no ripple.
  def test_a_tap_is_not_heard_while_the_guide_or_the_scene_is_showing
    assert_unheard(:drift) { [bright] }

    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    assert_unheard(:points) { [bright] }

    play_until { @tutorial.beat == :peek }
    assert_unheard(:peek) { [bright, next_dot] }

    play_until { @tutorial.beat == :warn }
    assert_unheard(:warn) { [bright, next_dot] }

    play_until { @tutorial.flights.any? }
    assert_unheard(:warn, "while the guide's own cost plays") { [bright, next_dot] }
    play_until { @tutorial.hud.dots_in_a_row.zero? }

    play_until { @tutorial.beat == :slide }
    assert_unheard(:slide) { [bright, next_dot] }

    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)
    assert_unheard(:runs) { [bright, next_dot] }

    play_until { @tutorial.beat == :ending }
    assert_unheard(:ending) { @tutorial.dots.to_a }
  end

  def test_the_turn_comes_back_exactly_when_the_guide_is_done_and_is_marked
    to_the_peek
    play_until { @tutorial.beat == :slide }
    refute_predicate @tutorial, :players_turn?
    before = @effects.rings.size
    play_until { @tutorial.beat == :aim_next }

    assert_predicate @tutorial, :players_turn?
    assert_equal Anchor.dot(Tutorial::NEXT), @tutorial.spotlight.to
    assert_equal [Style::SPAWN_RIPPLE], @effects.rings.drop(before).map(&:style), "a ripple opens from the dot that now answers"
    tap_on(next_dot)
    assert_equal :runs, @tutorial.beat
  end

  def test_the_last_pop_spawns_a_dot_under_them_all_and_hands_the_scene_over_as_it_is
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)

    assert_equal :runs, @tutorial.beat
    assert next_dot.bright?, "it bursts still bright"
    play_for(SCRIPT.gap + SCRIPT.quick + STEP)
    assert_equal [1, 10], shown, "two dots popped, less what the guide's tap cost"
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
    assert_equal [1, 10], shown
    assert_equal [1, 10.0], [@cabinet.game.score, @cabinet.game.countdown.remaining], "the game's own numbers"
    assert_equal @cabinet.game.dots.to_a, @tutorial.dots.to_a, "it draws the game's dots, every one as it is"
    assert_equal 3, @tutorial.dots.size, "no dot fades or is added"
  end

  # The maintainer: the first good "can also highlight the '1 in a row'",
  # and the first bad "can highlight that resetting to 0".
  def test_the_row_is_the_games_own_and_empty_from_the_start
    assert_equal [0, DotPopper::Rules::BONUS.dots_in_a_row, false], row_shown
    assert_nil @tutorial.row_notice
  end

  def test_the_first_pop_lights_the_row_and_rings_it_inside_the_beats_hold
    play_for(SCRIPT.drift + 0.5)
    @popped_at = @tutorial.now
    tap_on(bright)
    play_for(SCRIPT.gap + SCRIPT.flight + SCRIPT.gap + SCRIPT.flight)
    assert_equal 0, @tutorial.hud.dots_in_a_row, "the row waits its turn, after the point and the second"

    play_until { @tutorial.hud.dots_in_a_row == 1 }
    assert_equal :gain, @tutorial.row_notice.tone
    assert_equal Anchor.hud(:dots_in_a_row), @tutorial.spotlight.to, "and the light goes there"
    assert_operator SCRIPT.notice, :<, 1.0, "briefly"

    play_until { @tutorial.beat == :peek }
    assert_in_delta SCRIPT.gap + (3 * SCRIPT.flight) + (2 * SCRIPT.gap) + SCRIPT.hold,
                    @tutorial.now - @popped_at, 2 * STEP, "and the beat takes three flights and its hold"
  end

  def test_the_guides_mistake_empties_the_row_and_rings_it_red
    to_the_peek
    assert_equal 1, @tutorial.hud.dots_in_a_row

    play_until { @tutorial.hud.dots_in_a_row.zero? }
    assert_equal :alarm, @tutorial.row_notice.tone
  end

  def test_the_last_pop_lights_the_row_again_and_the_game_is_left_it
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)
    play_until { @tutorial.hud.dots_in_a_row == 1 }
    play_until(within: 900) { @tutorial.over? }

    assert_equal [1, 1], [@tutorial.hud.dots_in_a_row, @cabinet.game.dots_in_a_row]
  end

  def test_nothing_shows_what_a_full_row_brings
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    tap_on(next_dot)
    play_until(within: 900) { @tutorial.over? }

    refute @tutorial.hud.ready
    assert(@tutorial.dots.none?(&:bonus?))
    refute_includes @sounds.names, :bonus
    assert_equal 3, @tutorial.dots.size
  end

  def test_a_tap_on_empty_space_only_ripples
    play_for(SCRIPT.drift + 0.5)
    @tutorial.tap(5, 795)

    assert_equal :aim, @tutorial.beat
    assert_equal [Style::TOUCH_RIPPLE], @effects.rings.map(&:style).last(1)
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
    assert next_dot.bright?
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
    @cabinet.screen = DotPopper::Field.new(400, 850, R)

    assert bright.x.between?(R, 400 - R)
    assert_equal 400, @tutorial.field.width
  end

  # The rules hear the player's tap at once, by their usual sums; the
  # tutorial draws the dot bright, the dot spawned under it unborn, and
  # the HUD's numbers as they land, until it shows them.
  def test_the_game_hears_the_pop_at_the_tap_and_the_tutorial_shows_it_in_turn
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    game = @cabinet.game

    assert_equal [true, false], game.dots.map(&:popped?)
    assert_equal [1, 11.0, 1], [game.score, game.countdown.remaining, game.dots_in_a_row]
    assert_equal [[Tutorial::BRIGHT, false]], @tutorial.dots.map { [it.id, it.popped?] }
    assert_equal [0, 10], shown
    play_until { @tutorial.beat == :peek }
    assert_equal [[Tutorial::BRIGHT, true], [Tutorial::NEXT, false]], @tutorial.dots.map { [it.id, it.popped?] }
    assert_equal game.dots.to_a, @tutorial.dots.to_a
    assert_equal [1, 11], shown
  end

  def test_the_guides_mistake_is_charged_by_the_rules_and_heard_by_nothing_else
    heard = []
    @cabinet.subscribe { heard << it }
    to_the_peek
    play_until { @tutorial.flights.any? }

    assert_equal [0, 9.0, 0], [@cabinet.game.score, @cabinet.game.countdown.remaining, @cabinet.game.dots_in_a_row]
    assert_empty heard
  end

  def test_a_tap_on_the_popped_dot_never_reaches_the_game
    to_the_peek
    play_until { @tutorial.beat == :aim_next }
    before = @cabinet.game.then { [it.score, it.countdown.remaining, it.dots_in_a_row] }
    2.times { tap_on(bright) }

    assert_equal before, @cabinet.game.then { [it.score, it.countdown.remaining, it.dots_in_a_row] }
  end

  def test_its_clock_never_runs
    to_the_peek
    play_until(within: 900) { @tutorial.beat == :aim_next }
    play_for(2.0)

    assert_in_delta 9.0, @cabinet.game.countdown.remaining
    assert_in_delta 0.0, @cabinet.game.elapsed
  end

  def test_caught_up_it_shows_every_dot_of_the_game_as_it_is
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    rings = @effects.rings.size
    @tutorial.catch_up

    assert_equal @cabinet.game.dots.to_a, @tutorial.dots.to_a
    assert_equal [true, false], @tutorial.dots.map(&:popped?)
    assert_equal [Style::SPAWN_RIPPLE], @effects.rings.drop(rings).map(&:style), "the new dot is born"
  end

  private

  # Taps every dot of the block's, and beside them, and nothing changes.
  def assert_unheard(beat, note = nil)
    assert_equal beat, @tutorial.beat, note
    before = [@sounds.names.dup, @haptics.buzzes.dup, shown, @tutorial.dots.map(&:popped?), @tutorial.hud.dots_in_a_row,
              @tutorial.flights.size, @effects.reveals.size]
    rings = @effects.rings.size
    yield.each do |dot|
      tap_on(dot)
      @tutorial.tap(dot.x + (R * 0.5), dot.y)
    end
    @tutorial.tap(5, 795)

    assert_equal beat, @tutorial.beat, note
    assert_equal before, [@sounds.names, @haptics.buzzes, shown, @tutorial.dots.map(&:popped?), @tutorial.hud.dots_in_a_row,
                          @tutorial.flights.size, @effects.reveals.size], note
    assert_equal rings, @effects.rings.size, "#{note}: no ripple"
  end

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

  def row_shown = @tutorial.hud.then { [it.dots_in_a_row, it.size, it.ready] }

  def to_the_peek
    play_for(SCRIPT.drift + 0.5)
    tap_on(bright)
    play_until { @tutorial.beat == :warn }
  end

  # The Tutorial over +cabinet+'s game, started paused with its opening
  # dots from +center+, as the one way into a game starts it.
  def tutorial_on(cabinet, center, **)
    start_paused!(cabinet, Tutorial.opening(cabinet.field, center))
    Tutorial.new(cabinet:, **)
  end
end
