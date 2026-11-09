# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the gamepad cursor moves and looks. A push inside +dead_zone+
    # (of a full tilt, 1) is a stick at rest, so a worn stick does not
    # drift; past it, the push rises along a curve of power +curve+, so a
    # small tilt aims finely and a full one crosses the screen. At full
    # tilt the cursor crosses the window's diagonal in +crossing+
    # seconds, whatever its size, but never goes slower than +speed+
    # radii a second, so a small window keeps its feel. It gathers speed
    # over +ramp+ seconds rather than all at once, and only up to the
    # push's: a gentle push is at its speed almost at once, and letting
    # go stops it dead. The right trigger presses when pulled
    # to +trigger_press+ (of 1) and lets go below +trigger_release+, so a
    # trigger resting near the line does not chatter. The reticle's
    # +ring+ and its +ticks+ (from, to) are in radii, +line+ is its
    # stroke, in radii too, and +pip+ is the dot at its centre, in device
    # pixels across.
    class GamepadStyle < Data.define(:dead_zone, :curve, :speed, :crossing, :ramp, :trigger_press, :trigger_release,
                                    :ring, :ticks, :line, :pip)
    end

    # A push on a stick or d-pad, each way from -1 to 1; down is positive,
    # as on the screen.
    class Stick < Data.define(:x, :y)
      def self.rest = new(x: 0.0, y: 0.0)

      # The push of a d-pad's held arrows.
      def self.dpad(left:, right:, up:, down:)
        new(x: (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0), y: (down ? 1.0 : 0.0) - (up ? 1.0 : 0.0))
      end

      def initialize(x:, y:) = super(x: x.to_f, y: y.to_f)

      # Two pushes at once, as a stick and a d-pad, or two gamepads: their
      # sum, at most a full tilt each way.
      def +(other) = Stick.new(x: (x + other.x).clamp(-1.0, 1.0), y: (y + other.y).clamp(-1.0, 1.0))

      def rest? = x.zero? && y.zero?

      # The push as the cursor feels it: at rest inside the dead zone, then
      # rising from nothing at its edge to 1 at full tilt, along the curve,
      # in the stick's own direction.
      def shaped(dead_zone, curve)
        length = Math.hypot(x, y)
        return Stick.rest if length <= dead_zone

        strength = ((([length, 1.0].min - dead_zone) / (1.0 - dead_zone))**curve) / length
        Stick.new(x: x * strength, y: y * strength)
      end
    end

    # Where the gamepad aims, and whether it shows. It shows once a
    # gamepad is used and hides when the mouse or a finger is, waiting
    # where the mouse last was, so a player who picks up the pad starts
    # from there. It stays inside +area+, the window. +pace+ is how fast
    # it is going, of its top speed, as it gathers speed.
    class GamepadCursor < Data.define(:x, :y, :visible, :area, :style, :radius, :pace)
      # A hidden cursor in the middle of +area+.
      def self.centered(area, style:, radius:)
        new(x: area.center_x, y: area.center_y, visible: false, area:, style:, radius:)
      end

      def initialize(pace: 0.0, **) = super

      # The cursor +seconds+ later, pushed by +stick+. A push past the dead
      # zone moves it and shows it; a stick at rest stops it.
      def update(seconds, stick)
        push = stick.shaped(style.dead_zone, style.curve)
        return pace.zero? ? self : with(pace: 0.0) if push.rest?

        strength = Math.hypot(push.x, push.y)
        paced = [pace + (seconds / style.ramp), strength].min
        step = top_speed * seconds * paced / strength
        at(x + (push.x * step), y + (push.y * step)).with(pace: paced).show
      end

      # Graphics units a second at full tilt and full pace: enough to cross
      # the window's diagonal in the look's +crossing+, counting the half
      # of the ramp it spends gathering speed, and no less than +speed+
      # radii a second.
      def top_speed
        [Math.hypot(area.width, area.height) / (style.crossing - (style.ramp / 2.0)), style.speed * radius].max
      end

      def show = with(visible: true)

      # Hidden, waiting at (+to_x+, +to_y+), where the mouse or a finger is.
      def hide(to_x = x, to_y = y) = at(to_x, to_y).with(visible: false)

      # The cursor in a window of a new size, still inside it.
      def refit(area) = with(area:).at(x, y)

      def at(to_x, to_y) = with(x: to_x.to_f.clamp(area.x, area.right), y: to_y.to_f.clamp(area.y, area.bottom))
    end
  end
end
