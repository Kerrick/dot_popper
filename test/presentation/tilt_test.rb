# frozen_string_literal: true

require_relative "presentation_helper"

class TiltTest < Minitest::Test
  include PresentationTest

  ORIENTATIONS = %i[portrait portraitflipped landscape landscapeflipped].freeze

  # An accelerometer reads the push holding the device up, in its own
  # portrait axes (+x its right edge, +y its top edge), so a device held
  # upright with its edge +up+ (:top, :bottom, :left or :right, the
  # device's own edges) reads 1 g toward that edge.
  def upright(up, lean: 0.0, toward: nil)
    x, y = { top: [0.0, 1.0], bottom: [0.0, -1.0], right: [1.0, 0.0], left: [-1.0, 0.0] }.fetch(up)
    lx, ly = toward ? { top: [0.0, 1.0], bottom: [0.0, -1.0], right: [1.0, 0.0], left: [-1.0, 0.0] }.fetch(toward) : [0, 0]
    Reading.new(x: (x * Math.cos(lean)) + (lx * Math.sin(lean)), y: (y * Math.cos(lean)) + (ly * Math.sin(lean)))
  end

  def pull(reading, orientation) = Pull.from_device(reading.x, reading.y, orientation)

  def assert_pull(expected_x, expected_y, actual)
    assert_in_delta expected_x, actual.x, 1e-9, "x of #{actual}"
    assert_in_delta expected_y, actual.y, 1e-9, "y of #{actual}"
  end

  # Upright, in each orientation, the dots fall to the screen's bottom,
  # as they do without a sensor.
  def test_a_device_held_upright_drops_the_dots_down_the_screen_in_every_orientation
    # The edge that is up for each orientation, per SDL_video.h:
    # landscape is "the right side up", landscapeflipped the left side.
    { portrait: :top, portraitflipped: :bottom, landscape: :right, landscapeflipped: :left }.each do |orientation, up|
      assert_pull 0.0, 1.0, pull(upright(up), orientation)
    end
  end

  def test_in_portrait_lowering_the_left_edge_rolls_the_dots_to_the_screens_left
    # Upright, then turned so the push holding it up leans toward its
    # right edge: its left edge goes down.
    tilted = pull(upright(:top, lean: 0.5, toward: :right), :portrait)

    assert_operator tilted.x, :<, 0.0
    assert_operator tilted.y, :>, 0.0
  end

  def test_in_portrait_flipped_lowering_the_screens_left_side_rolls_the_dots_left
    # Upside down, the screen's left side is the device's right edge, so
    # the push leans toward the device's left edge.
    tilted = pull(upright(:bottom, lean: 0.5, toward: :left), :portraitflipped)

    assert_operator tilted.x, :<, 0.0
  end

  def test_in_landscape_lowering_the_screens_left_side_rolls_the_dots_to_the_screens_left
    # Landscape stands the device on its left edge, its top edge at the
    # screen's left. Lowering that side leans the push toward the
    # device's bottom edge, at the screen's right.
    tilted = pull(upright(:right, lean: 0.5, toward: :bottom), :landscape)

    assert_operator tilted.x, :<, 0.0
    assert_operator tilted.y, :>, 0.0
  end

  def test_in_landscape_lowering_the_screens_right_side_rolls_the_dots_to_the_screens_right
    tilted = pull(upright(:right, lean: 0.5, toward: :top), :landscape)

    assert_operator tilted.x, :>, 0.0
  end

  def test_in_landscape_flipped_lowering_the_screens_left_side_rolls_the_dots_left
    # Flipped, the device stands on its right edge, its bottom edge at the
    # screen's left; lowering that side leans the push toward its top.
    tilted = pull(upright(:left, lean: 0.5, toward: :top), :landscapeflipped)

    assert_operator tilted.x, :<, 0.0
    assert_operator tilted.y, :>, 0.0
  end

  def test_held_upside_down_the_dots_fall_up_the_screen
    # The edge that is down for each orientation.
    { portrait: :bottom, portraitflipped: :top, landscape: :left, landscapeflipped: :right }.each do |orientation, up|
      assert_pull 0.0, -1.0, pull(upright(up), orientation)
    end
  end

  def test_lying_flat_the_dots_feel_no_pull_across_the_screen
    ORIENTATIONS.each { assert_pull 0.0, 0.0, Pull.from_device(0.0, 0.0, it) }
  end

  def test_an_unknown_orientation_is_the_devices_own
    assert_equal Pull.from_device(0.3, 0.8, :portrait), Pull.from_device(0.3, 0.8, :unknown)
  end

  def test_a_pull_of_one_is_the_piles_own_gravity
    assert_equal [0.0, Look::PILE.gravity_for(R)], Pull.down.gravity(Look::PILE.gravity_for(R))
  end

  def test_a_reading_in_meters_a_second_squared_is_turned_to_g
    reading = Reading.si(0.0, Pull::STANDARD_GRAVITY, 0.0)

    assert_in_delta 1.0, reading.y
  end

  def test_a_fake_tilt_is_read_from_x_comma_y
    assert_equal Reading.new(x: 0.6, y: 0.0), Reading.parse("0.6,0")
    assert_equal Reading.new(x: -0.25, y: 1.0), Reading.parse(" -0.25 , 1 ")
    assert_nil Reading.parse(nil)
    assert_nil Reading.parse("")
    assert_nil Reading.parse("left")
    assert_nil Reading.parse("1,2,3")
  end

  def test_the_fake_tilt_the_docs_give_rolls_the_dots_sideways
    fake = Reading.parse("0.6,0")

    assert_pull(-0.6, 0.0, Pull.from_device(fake.x, fake.y, :portrait))
  end

  # The low-pass filter.

  def test_the_filter_eases_toward_a_reading_by_its_time_constant
    filter = LowPass.new(value: Pull.down, time_constant: 0.2).update(0.2, Pull.new(x: 1.0, y: 1.0))

    assert_in_delta 1 - Math.exp(-1), filter.value.x
    assert_in_delta 1.0, filter.value.y
  end

  def test_the_filter_does_not_depend_on_the_frame_rate
    target = Pull.new(x: -1.0, y: 0.0)
    once = LowPass.new(value: Pull.down, time_constant: 0.2).update(0.1, target)
    twice = LowPass.new(value: Pull.down, time_constant: 0.2).update(0.05, target).update(0.05, target)

    assert_in_delta once.value.x, twice.value.x
    assert_in_delta once.value.y, twice.value.y
  end

  def test_the_filter_smooths_a_jittery_reading
    filter = LowPass.new(value: Pull.down, time_constant: Look::TILT.smoothing)
    xs = 120.times.map do |i|
      filter = filter.update(1 / 60.0, Pull.new(x: i.even? ? 0.2 : -0.2, y: 1.0))
      filter.value.x
    end

    assert_operator xs.last(60).map(&:abs).max, :<, 0.03
  end

  def test_a_calm_tilt_turns_more_slowly
    assert_operator Look::CALM_TILT.smoothing, :>, Look::TILT.smoothing
  end

  # Shakes.

  def test_a_sharp_jolt_is_a_shake_and_holding_still_is_not
    sensor = ShakeSensor.start(Look::TILT, upright(:top))
    10.times { sensor = sensor.update(1 / 60.0, upright(:top)) }

    refute_predicate sensor, :shaken?
    sensor = sensor.update(1 / 60.0, Reading.new(x: 2.0, y: -1.0, z: 0.5))

    assert_predicate sensor, :shaken?
    assert_operator sensor.jolt, :>, Look::TILT.shake
  end

  def test_tilting_slowly_is_not_a_shake
    sensor = ShakeSensor.start(Look::TILT, upright(:top))
    120.times do |i|
      sensor = sensor.update(1 / 60.0, upright(:top, lean: i / 120.0 * 1.5, toward: :right))

      refute_predicate sensor, :shaken?
    end
  end

  def test_after_a_shake_the_sensor_waits_out_its_cooldown
    sensor = ShakeSensor.start(Look::TILT, upright(:top)).update(1 / 60.0, Reading.new(x: 3.0, y: 1.0))

    assert_predicate sensor, :shaken?
    shakes = 30.times.count do |i|
      sensor = sensor.update(Look::TILT.cooldown / 40, Reading.new(x: i.even? ? -3.0 : 3.0, y: 1.0))
      sensor.shaken?
    end

    assert_equal 0, shakes
    60.times { sensor = sensor.update(1 / 60.0, upright(:top)) }
    sensor = sensor.update(1 / 60.0, Reading.new(x: 3.0, y: 1.0))

    assert_predicate sensor, :shaken?
  end

  def test_a_shake_throws_harder_the_harder_it_is_up_to_a_cap
    look = Look::TILT

    assert_in_delta 0.0, look.kick_for(0.0)
    assert_in_delta 0.0, look.kick_for(look.shake)
    assert_operator look.kick_for(look.shake + 1.0), :<, look.kick_for(look.shake + 1.5)
    assert_in_delta look.most_kick, look.kick_for(100.0)
  end

  def test_a_thrown_ball_goes_against_the_pull_within_the_spread
    fling = Look::TILT.fling
    random = Random.new(3)
    50.times do
      vx, vy = fling.velocity(Pull.down, 10.0, R, random)
      speed = Math.hypot(vx, vy)

      assert_operator vy, :<, 0.0
      assert_operator speed, :<=, (10.0 * R) + 1e-9
      assert_operator speed, :>=, (10.0 * R * fling.least) - 1e-9
    end
  end

  # The gamepad's right stick.

  def test_a_stick_at_rest_drops_the_dots_as_before
    assert_equal Pull.down, Pull.from_stick(Stick.rest, 0.2)
    assert_equal Pull.down, Pull.from_stick(Stick.new(x: 0.1, y: -0.1), 0.2)
  end

  def test_a_pushed_stick_pulls_its_way_at_full_gravity
    assert_pull(-1.0, 0.0, Pull.from_stick(Stick.new(x: -0.5, y: 0.0), 0.2))
    assert_pull 0.0, -1.0, Pull.from_stick(Stick.new(x: 0.0, y: -1.0), 0.2)
    right_down = Pull.from_stick(Stick.new(x: 0.6, y: 0.6), 0.2)

    assert_in_delta 1.0, right_down.length
    assert_in_delta right_down.x, right_down.y
  end

  # Tilt, frame by frame.

  def test_with_nothing_to_tilt_it_the_pile_keeps_falling_down
    tilt = Tilt.new(Look::TILT)
    step = tilt.update(1 / 60.0)

    assert_equal Pull.down, step.pull
    refute step.wake
    assert_in_delta 0.0, step.kick
  end

  def test_a_steady_tilt_turns_the_pull_and_wakes_the_pile_as_it_does
    tilt = Tilt.new(Look::TILT, orientation: :portrait)
    steps = 60.times.map { tilt.update(1 / 60.0, reading: Reading.new(x: 0.6, y: 0.0)) }

    assert_in_delta(-0.6, steps.last.pull.x, 0.01)
    assert_in_delta 0.0, steps.last.pull.y, 0.01
    assert steps.first.wake
    refute steps.last.wake, "a settled pull leaves sleeping dots asleep"
  end

  def test_the_screens_orientation_turns_the_reading
    tilt = Tilt.new(Look::TILT, orientation: :landscape)
    60.times { tilt.update(1 / 60.0, reading: Reading.new(x: 0.0, y: -0.6)) }

    assert_in_delta(-0.6, tilt.pull.x, 0.01)
  end

  def test_a_pushed_stick_wins_over_the_accelerometer
    tilt = Tilt.new(Look::TILT)
    90.times { tilt.update(1 / 60.0, reading: upright(:top), stick: Stick.new(x: 0.0, y: -1.0)) }

    assert_in_delta(-1.0, tilt.pull.y, 0.01)
  end

  def test_a_shake_kicks_and_a_calm_one_never_does
    [Look::TILT, Look::CALM_TILT].each do |look|
      tilt = Tilt.new(look)
      5.times { tilt.update(1 / 60.0, reading: upright(:top)) }
      step = tilt.update(1 / 60.0, reading: Reading.new(x: 3.0, y: -1.0, z: 1.0))

      if look.shakes then assert_operator step.kick, :>, 0.0
      else assert_in_delta 0.0, step.kick
      end
    end
  end

  def test_a_stick_never_shakes
    tilt = Tilt.new(Look::TILT)
    kicks = 30.times.map { tilt.update(1 / 60.0, stick: Stick.new(x: it.even? ? 1.0 : -1.0, y: 0.0)).kick }

    assert kicks.all?(&:zero?)
  end

  # The hint.

  class Store
    attr_reader :text

    def initialize(text = nil) = @text = text
    def read = @text
    def write(text) = @text = text
  end

  def test_the_hint_shows_on_the_first_few_game_overs_only
    store = Store.new
    lines = 5.times.map { TiltHint.new(store, Look::TILT).offer(gamepad: false, accelerometer: true, device: "iPad") }

    assert_equal ["Tilt your iPad to roll the dots."] * Look::TILT.hint_rounds, lines.compact
    assert_equal Look::TILT.hint_rounds.to_s, store.text
  end

  def test_with_a_gamepad_the_hint_says_to_push_the_stick
    hint = TiltHint.new(Store.new, Look::TILT)

    assert_equal "Push the right stick to roll the dots.",
                 hint.offer(gamepad: true, accelerometer: true, device: "iPad")
  end

  def test_with_no_way_to_tilt_there_is_no_hint_and_none_is_counted
    store = Store.new

    assert_nil TiltHint.new(store, Look::TILT).offer(gamepad: false, accelerometer: false, device: "device")
    assert_nil store.text
  end

  def test_the_device_is_named_on_ios_and_generic_elsewhere
    assert_equal "iPad", TiltHint.device("iOS", 1024, 768)
    assert_equal "iPhone", TiltHint.device("iOS", 393, 852)
    assert_equal "device", TiltHint.device("Android", 1024, 768)
  end

  def test_a_tilted_pile_has_a_lid
    walls = PileWalls.new(width: 800, height: 600, lid: true).segments

    assert_includes walls, [0.0, 0.0, 800.0, 0.0]
    refute_includes PileWalls.new(width: 800, height: 600).segments, [0.0, 0.0, 800.0, 0.0]
  end
end
