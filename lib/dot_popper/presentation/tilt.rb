# frozen_string_literal: true

module DotPopper
  module Presentation
    # How tilting the game-over pile feels. Once a game is over its dots
    # are a toy, and a player may tilt a tablet, or push a gamepad's right
    # stick, to roll them about (Shell::Tilting).
    #
    # +smoothing+ is the low-pass filter's time constant in seconds, so
    # the pull follows the hand and not its tremor. Bodies that have
    # fallen asleep are woken when the pull has moved more than +wake+ (in
    # g) since they were last woken. A jolt is the reading's change from
    # its own +settle+-second average, of more than +shake+ g, and a shake
    # is a jolt followed within +reversal+ seconds by one the opposite
    # way, so a single bump is not a shake; it throws every ball at +least_kick+ radii a second, and +kick+
    # more for each g past that, at most +most_kick+, and the next shake
    # counts only after
    # +cooldown+ seconds, each ball as +fling+ (a Throw) says. A calm
    # pile (+shakes+ false) never throws a ball. A stick inside
    # +dead_zone+ is at rest.
    class TiltStyle < Data.define(:smoothing, :wake, :shake, :reversal, :settle, :cooldown, :least_kick, :kick, :most_kick,
                                 :shakes, :fling, :dead_zone)
      # The speed, in radii a second, a jolt of +jolt+ g throws a ball:
      # none for a jolt no bigger than a shake, and at least +least_kick+
      # for one that is, so even a gentle shake tosses the dots high.
      def kick_for(jolt)
        return 0.0 if jolt <= shake

        (least_kick + ((jolt - shake) * kick)).clamp(0.0, most_kick)
      end
    end

    # The way the dots are pulled, in g, on the screen: +x+ to the right,
    # +y+ down. A pull of 1 is the pile's own gravity (PileStyle), so a
    # tablet held upright, or a stick at rest, drops the dots as before.
    class Gravity < Data.define(:x, :y)
      STANDARD_GRAVITY = 9.80665 # m/s², a reading of 1 g

      def self.down = new(x: 0.0, y: 1.0)

      def initialize(x:, y:) = super(x: x.to_f, y: y.to_f)

      # The pull for an accelerometer reading of +x+ and +y+, in g, on a
      # screen turned to +orientation+ (Lota::Window.display_orientation).
      #
      # SDL (and so LÖVE) gives the reading in the device's own axes, as
      # it is held in its natural orientation, portrait on a tablet: +x
      # toward its right edge, +y toward its top edge. The reading is the
      # push that holds the device up, so it points away from the ground:
      # held upright it reads +y 1 g, and the dots should fall the other
      # way, toward the device's bottom edge. SDL never turns the axes as
      # the screen turns, so this does, by how the screen sits on the
      # device:
      #
      # - portrait: the screen's right is the device's +x and its down is
      #   the device's -y.
      # - portraitflipped: upside down, both reversed.
      # - landscape: "the right side up" (SDL_video.h), so the screen's
      #   up is the device's +x, and its right the device's -y, where the
      #   bottom edge went.
      # - landscapeflipped: the left side up, so the screen's up is the
      #   device's -x, and its right the device's +y.
      #
      # Any other orientation is the device's natural one: a desktop's
      # screen and its sensor, if it has one, never turn apart.
      def self.from_device(x, y, orientation)
        case orientation
        when :portraitflipped then new(x:, y: -y)
        when :landscape then new(x: y, y: x)
        when :landscapeflipped then new(x: -y, y: -x)
        else new(x: -x, y:)
        end
      end

      # The pull a gamepad's right stick asks for: its own direction, at
      # the pile's full gravity, or straight down while it is at rest.
      def self.from_stick(stick, dead_zone)
        length = Math.hypot(stick.x, stick.y)
        return down if length <= dead_zone

        new(x: stick.x / length, y: stick.y / length)
      end

      def +(other) = Gravity.new(x: x + other.x, y: y + other.y)
      def -(other) = Gravity.new(x: x - other.x, y: y - other.y)
      def *(other) = Gravity.new(x: x * other, y: y * other)

      def length = Math.hypot(x, y)

      # The pull as a gravity of +strength+, in graphics units a second
      # squared, for World#gravity=.
      def gravity(strength) = [x * strength, y * strength]
    end

    # Its old name, until no caller says it.
    Pull = Gravity

    # A low-pass filter: a value that eases toward each new reading,
    # covering 63% of the way in +time_constant+ seconds, however long
    # the frames are. It filters Gravity values, or any value that adds, subtracts
    # and scales as they do.
    class LowPass < Data.define(:value, :time_constant)
      def update(seconds, target)
        return with(value: target) unless time_constant.positive?

        share = 1.0 - Math.exp(-seconds / time_constant)
        with(value: value + ((target - value) * share))
      end
    end

    # An accelerometer reading in three axes, in g, so a shake can be
    # measured however the device is held.
    class Reading < Data.define(:x, :y, :z)
      def self.still = new(x: 0.0, y: 0.0, z: 0.0)

      def initialize(x:, y:, z: 0.0) = super(x: x.to_f, y: y.to_f, z: z.to_f)

      # A reading written "x,y", in g, as DOT_POPPER_FAKE_TILT gives one;
      # nil for anything else.
      def self.parse(text)
        x, y, rest = text.to_s.split(",").map { Float(it.strip, exception: false) }
        new(x:, y:) if x && y && rest.nil?
      end

      # A reading from Lota::Sensor, in meters a second squared.
      def self.si(x, y, z) = new(x:, y:, z:) * (1.0 / Gravity::STANDARD_GRAVITY)

      def +(other) = Reading.new(x: x + other.x, y: y + other.y, z: z + other.z)
      def -(other) = Reading.new(x: x - other.x, y: y - other.y, z: z - other.z)
      def *(other) = Reading.new(x: x * other, y: y * other, z: z * other)

      def length = Math.sqrt((x * x) + (y * y) + (z * z))
      def dot(other) = (x * other.x) + (y * other.y) + (z * other.z)
    end

    # Notices a shake: a reading that jumps away from its recent average
    # by more than the theme's +shake+, the high-pass part of the signal,
    # and then, within the theme's +reversal+ seconds, jumps as far the
    # other way. +first+ is the jolt waiting for its reversal, or nil, and
    # +waiting+ how much longer it waits.
    # After one, it waits out the +cooldown+ before it notices another, so
    # a single shake throws the dots once. +jolt+ is the size of the
    # shake it noticed in the last update, in g, or 0.
    class ShakeSensor < Data.define(:average, :resting, :jolt, :first, :waiting, :style)
      def self.start(style, reading) = new(average: LowPass.new(value: reading, time_constant: style.settle),
                                          resting: 0.0, jolt: 0.0, first: nil, waiting: 0.0, style:)

      def update(seconds, reading)
        change = reading - average.value
        settled = with(average: average.update(seconds, reading), resting: resting - seconds, jolt: 0.0,
                       waiting: waiting - seconds)
        settled = settled.with(first: nil) if settled.waiting <= 0.0
        return settled unless change.length > style.shake && resting <= 0.0

        settled.jolted(change)
      end

      # A jolt of +change+: the shake, if it reverses the jolt waiting,
      # or else the jolt to wait on.
      def jolted(change)
        if first&.dot(change)&.negative?
          with(resting: style.cooldown, jolt: [change.length, first.length].max, first: nil, waiting: 0.0)
        else
          with(first: change, waiting: style.reversal)
        end
      end

      def shaken? = jolt.positive?
    end

    # What a frame of tilting asks of the pile: the +pull+ to fall
    # toward, whether to +wake+ the dots asleep in it, since the pull has
    # moved a good way since they last were, and the +kick+ of a shake, in
    # radii a second, or 0.
    class TiltStep < Data.define(:pull, :wake, :kick); end

    # The tilt of one game-over pile, from an accelerometer, a gamepad's
    # right stick, or both, as it comes in each frame. It begins pulling
    # straight down, as the pile does without it.
    class Tilt
      def initialize(style, orientation: :portrait)
        @style = style
        @orientation = orientation
        @pull = LowPass.new(value: Gravity.down, time_constant: style.smoothing)
        @woken = Gravity.down
        @shakes = nil
      end

      def pull = @pull.value

      # The screen turned, as a tablet does.
      attr_writer :orientation

      # A frame of +seconds+, with the accelerometer's +reading+ (a
      # Reading, or nil with none) and the right +stick+. A stick pushed
      # past its dead zone wins over the accelerometer, since it was
      # pushed on purpose.
      def update(seconds, reading: nil, stick: Stick.rest)
        @pull = @pull.update(seconds, target(reading, stick))
        TiltStep.new(pull:, wake: woken?, kick: kick(seconds, reading))
      end

      private

      def target(reading, stick)
        pushed = Math.hypot(stick.x, stick.y) > @style.dead_zone
        return Gravity.from_stick(stick, @style.dead_zone) if pushed || reading.nil?

        Gravity.from_device(reading.x, reading.y, @orientation)
      end

      def woken?
        return false if (pull - @woken).length <= @style.wake

        @woken = pull
        true
      end

      def kick(seconds, reading)
        return 0.0 unless @style.shakes && reading

        @shakes = @shakes ? @shakes.update(seconds, reading) : ShakeSensor.start(@style, reading)
        @style.kick_for(@shakes.jolt)
      end
    end

    # Which way a shaken ball is thrown: against the pull, so up when the
    # dots fall down, spread up to +spread+ radians either side, at
    # between +least+ and all of the shake's +speed+. Returns a velocity
    # in graphics units a second, for a dot of +radius+.
    class Throw < Data.define(:spread, :least)
      def velocity(pull, speed, radius, random)
        away = Math.atan2(-pull.y, -pull.x)
        angle = away + random.rand(-spread..spread)
        reach = speed * radius * random.rand(least..1.0)
        [Math.cos(angle) * reach, Math.sin(angle) * reach]
      end
    end
  end
end
