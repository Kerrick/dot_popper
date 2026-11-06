# frozen_string_literal: true

module DotPopper
  module Presentation
    # How tilting the game-over pile feels. Once a round is over its dots
    # are a toy, and a player may tilt a tablet, or push a gamepad's right
    # stick, to roll them about (Shell::Tilting).
    #
    # +smoothing+ is the low-pass filter's time constant in seconds, so
    # the pull follows the hand and not its tremor. Bodies that have
    # fallen asleep are woken when the pull has moved more than +wake+ (in
    # g) since they were last woken. A shake is a jolt, the reading's
    # change from its own +settle+-second average, of more than +shake+
    # g; it throws every ball at +least_kick+ radii a second, and +kick+
    # more for each g past that, at most +most_kick+, and the next shake
    # counts only after
    # +cooldown+ seconds, each ball as +fling+ (a Throw) says. A calm
    # pile (+shakes+ false) never throws a ball. A stick inside +dead_zone+ is at rest. The hint shows on the
    # first +hint_rounds+ Game Overs, under the prompt, at +hint_alpha+ of
    # the prompt's: +stick_hint+ to a player at a gamepad,
    # +drag_tilt_hint+ with a pointer and an accelerometer,
    # +drag_hint+ with a pointer alone, or +tilt_hint+ with an
    # accelerometer alone, %s naming the device.
    class TiltLook < Data.define(:smoothing, :wake, :shake, :settle, :cooldown, :least_kick, :kick, :most_kick,
                                 :shakes, :fling, :dead_zone, :hint_rounds, :hint_alpha, :tilt_hint, :stick_hint,
                                 :drag_hint, :drag_tilt_hint)
      # The speed, in radii a second, a jolt of +jolt+ g throws a ball:
      # none for a jolt no bigger than a shake, and at least +least_kick+
      # for one that is, so even a gentle shake tosses the dots high.
      def kick_for(jolt)
        return 0.0 if jolt <= shake

        (least_kick + ((jolt - shake) * kick)).clamp(0.0, most_kick)
      end
    end

    # The way the dots are pulled, in g, on the screen: +x+ to the right,
    # +y+ down. A pull of 1 is the pile's own gravity (PileLook), so a
    # tablet held upright, or a stick at rest, drops the dots as before.
    class Pull < Data.define(:x, :y)
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

      def +(other) = Pull.new(x: x + other.x, y: y + other.y)
      def -(other) = Pull.new(x: x - other.x, y: y - other.y)
      def *(other) = Pull.new(x: x * other, y: y * other)

      def length = Math.hypot(x, y)

      # The pull as a gravity of +strength+, in graphics units a second
      # squared, for World#gravity=.
      def gravity(strength) = [x * strength, y * strength]
    end

    # A low-pass filter: a value that eases toward each new reading,
    # covering 63% of the way in +time_constant+ seconds, however long
    # the frames are. It filters Pulls, or any value that adds, subtracts
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
      def self.si(x, y, z) = new(x:, y:, z:) * (1.0 / Pull::STANDARD_GRAVITY)

      def +(other) = Reading.new(x: x + other.x, y: y + other.y, z: z + other.z)
      def -(other) = Reading.new(x: x - other.x, y: y - other.y, z: z - other.z)
      def *(other) = Reading.new(x: x * other, y: y * other, z: z * other)

      def length = Math.sqrt((x * x) + (y * y) + (z * z))
    end

    # Notices a shake: a reading that jumps away from its recent average
    # by more than the look's +shake+, the high-pass part of the signal.
    # After one, it waits out the +cooldown+ before it notices another, so
    # a single shake throws the dots once. +jolt+ is the size of the
    # shake it noticed in the last update, in g, or 0.
    class ShakeSensor < Data.define(:average, :resting, :jolt, :look)
      def self.start(look, reading) = new(average: LowPass.new(value: reading, time_constant: look.settle),
                                          resting: 0.0, jolt: 0.0, look:)

      def update(seconds, reading)
        change = (reading - average.value).length
        settled = with(average: average.update(seconds, reading), resting: resting - seconds, jolt: 0.0)
        return settled unless change > look.shake && resting <= 0.0

        settled.with(resting: look.cooldown, jolt: change)
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
      def initialize(look, orientation: :portrait)
        @look = look
        @orientation = orientation
        @pull = LowPass.new(value: Pull.down, time_constant: look.smoothing)
        @woken = Pull.down
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
        pushed = Math.hypot(stick.x, stick.y) > @look.dead_zone
        return Pull.from_stick(stick, @look.dead_zone) if pushed || reading.nil?

        Pull.from_device(reading.x, reading.y, @orientation)
      end

      def woken?
        return false if (pull - @woken).length <= @look.wake

        @woken = pull
        true
      end

      def kick(seconds, reading)
        return 0.0 unless @look.shakes && reading

        @shakes = @shakes ? @shakes.update(seconds, reading) : ShakeSensor.start(@look, reading)
        @look.kick_for(@shakes.jolt)
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

    # The light line on Game Over that says the pile can be played with,
    # on its first few showings ever, one way for the device in hand: how
    # to push, with a gamepad, since a player holding one is not touching
    # the screen; how to drag and tilt, on a tablet or phone; how to drag,
    # with a mouse or a touchscreen alone; or how to tilt. It remembers how many times it has
    # shown through a store that answers +read+ and +write(text)+, as the
    # Tutor's does.
    class TiltHint
      def initialize(store, look)
        @store = store
        @look = look
        @shown = Integer(store.read.to_s.strip, exception: false) || 0
      end

      attr_reader :shown

      # The line for a Game Over with these ways to play with the pile, as
      # a ByInput, counting it as shown, or nil once it has shown enough,
      # or with no way to play. A player at the gamepad is told about its
      # A and right stick, and one at a mouse or a screen about dragging
      # and tilting. +device+ names the thing to tilt: "iPad", say.
      # +pointer+ says whether a mouse or a finger can drag the dots.
      def offer(gamepad:, accelerometer:, device:, pointer: false)
        return if @shown >= @look.hint_rounds

        by_hand = if pointer && accelerometer then format(@look.drag_tilt_hint, device)
                  elsif pointer then @look.drag_hint
                  elsif accelerometer then format(@look.tilt_hint, device)
                  end
        by_pad = @look.stick_hint if gamepad
        return unless by_hand || by_pad

        @shown += 1
        @store.write(@shown.to_s)
        ByInput.new(touch: by_hand || by_pad, mouse: by_hand || by_pad, gamepad: by_pad || by_hand)
      end

      # What to call the device in the hint: an iPad or iPhone on iOS, by
      # its screen's shorter side in points, or "device" elsewhere.
      def self.device(os, width, height)
        return "device" unless os == "iOS"

        [width, height].min >= 600 ? "iPad" : "iPhone"
      end
    end
  end
end
