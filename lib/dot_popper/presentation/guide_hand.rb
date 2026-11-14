# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the Tutorial's guide hand moves, in seconds and radii: one tap's
    # loop, how long it glides from one dot to another and fades in or
    # out, where it rests between taps (+rest+, an [x, y] offset from the
    # dot, down and to the right), where it waits beside a dot it will not
    # tap again (+hover+, an [x, y] offset from that dot, which the
    # Tutorial keeps on screen), how it wags its finger there, "no"
    # (+wag+, a WagStyle), and how long it then holds still (+settle+).
    class GuideStyle < Data.define(:loop, :glide, :fade, :rest, :hover, :wag, :settle)
      # How long it waits, from arriving, before it may move on.
      def waiting = wag.time + settle
    end

    # A finger-wag, "no": +cycles+ times side to side in +time+ seconds,
    # turning about the wrist by up to +angle+ radians each way, easing
    # in and out of it.
    class WagStyle < Data.define(:cycles, :time, :angle)
      # How far it is turned +elapsed+ seconds in, in radians.
      def turn(elapsed)
        return 0.0 unless elapsed.between?(0.0, time)

        share = elapsed / time
        angle * Math.sqrt(Math.sin(Math::PI * share)) * Math.sin(2 * Math::PI * cycles * share)
      end
    end

    # Where the guide hand is at one moment, and how it is pressing:
    # +press+ from 0 (lifted) to 1 (down), +since_press+ the seconds since
    # this tap went down, or nil between taps, +alpha+ how much of it
    # shows, and +turn+ how far it is turned as it wags, in radians. The
    # shell draws it as the player's own hand: a pointing hand, a mouse
    # pointer, or a gamepad's reticle and its A button.
    class GuidePose < Data.define(:x, :y, :press, :since_press, :alpha, :turn)
      def initialize(x:, y:, press:, since_press:, alpha:, turn: 0.0) = super

      # This pose +share+ of the way to +other+.
      def toward(other, share)
        GuidePose.new(x: x + ((other.x - x) * share), y: y + ((other.y - y) * share),
                      press: press + ((other.press - press) * share), since_press: other.since_press,
                      alpha: alpha + ((other.alpha - alpha) * share), turn: turn + ((other.turn - turn) * share))
      end
    end

    # The guide hand that shows the player what to do, without a word: it
    # taps a dot over and over (+mode+ :tap), waits beside one, holding
    # back (:hover), or fades away (:gone). +to+ is the dot's Anchor, and
    # since +at+ it glides there from where the hand was before
    # (+before+, the GuideHand it was), or fades in if it was nowhere.
    class GuideHand < Data.define(:mode, :to, :at, :before, :style)
      # One tap's loop: it comes in from rest, goes down, holds, comes up,
      # and goes back to rest, as fractions of the loop.
      ARRIVES = 0.25
      PRESSED = 0.34
      LIFTS = 0.44
      LIFTED = 0.53
      RESTS = 0.78

      def self.none(style) = new(mode: :gone, to: nil, at: -Float::INFINITY, before: nil, style:)

      def tapping(anchor, now) = moving(:tap, anchor, now)
      def hovering(anchor, now) = moving(:hover, anchor, now)
      def gone(now) = mode == :gone ? self : with(mode: :gone, to: nil, at: now, before: without_before)

      # Its pose at +now+ (GuidePose) among +dots+ of +radius+, or nil
      # where it shows nowhere.
      def pose(now, dots, radius)
        share = (now - at) / (mode == :gone ? style.fade : style.glide)
        earlier = before&.pose(now, dots, radius) if share < 1
        return earlier&.with(alpha: earlier.alpha * (1 - share)) if mode == :gone

        own = own_pose(now, dots, radius) or return
        return own if before && share >= 1
        return own.with(alpha: ((now - at) / style.fade).clamp(0.0, 1.0)) unless earlier

        earlier.toward(own, Ease.in_out_sine(share))
      end

      private

      def moving(mode, anchor, now)
        return self if mode == self.mode && anchor == to

        with(mode:, to: anchor, at: now, before: to ? without_before : nil)
      end

      # This hand, forgetting where it came from, so hands never chain.
      def without_before = with(before: nil)

      def own_pose(now, dots, radius)
        point = to&.point(dots, {}, radius) or return
        x, y = point
        elapsed = now - at - (before ? style.glide : 0.0)
        mode == :tap ? tap_pose(x, y, elapsed, radius) : hover_pose(x, y, elapsed, radius)
      end

      # Comes in from rest, presses, lifts, and goes back, over and over.
      def tap_pose(x, y, elapsed, radius)
        t = elapsed.negative? ? 0.0 : (elapsed % style.loop) / style.loop
        away = if t < ARRIVES then 1 - Ease.in_out_sine(t / ARRIVES)
               elsif t < LIFTED then 0.0
               elsif t < RESTS then Ease.in_out_sine((t - LIFTED) / (RESTS - LIFTED))
               else 1.0
               end
        rest_x, rest_y = style.rest
        GuidePose.new(x: x + (rest_x * radius * away), y: y + (rest_y * radius * away), press: press_at(t),
                      since_press: t >= ARRIVES && t < RESTS ? (t - ARRIVES) * style.loop : nil, alpha: 1.0)
      end

      def press_at(t)
        if t.between?(ARRIVES, PRESSED) then Ease.out_quad((t - ARRIVES) / (PRESSED - ARRIVES))
        elsif t.between?(PRESSED, LIFTS) then 1.0
        elsif t.between?(LIFTS, LIFTED) then 1 - Ease.in_quad((t - LIFTS) / (LIFTED - LIFTS))
        else 0.0
        end
      end

      # At the place it waits, never pressing: it wags its finger, "no",
      # then holds still.
      def hover_pose(x, y, elapsed, _radius)
        GuidePose.new(x:, y:, press: 0.0, since_press: nil, alpha: 1.0, turn: style.wag.turn(elapsed))
      end
    end
  end
end
