# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the Tutorial's ghost hand moves, in seconds and radii: one tap's
    # loop, how long it glides from one dot to another and fades in or
    # out, where it rests between taps (+rest+, an [x, y] offset from the
    # dot, down and to the right), and where it waits beside a dot it will
    # not tap again (+hover+), bobbing by +bob+.
    class GhostLook < Data.define(:loop, :glide, :fade, :rest, :hover, :bob); end

    # Where the ghost hand is at one moment, and how it is pressing:
    # +press+ from 0 (lifted) to 1 (down), +since_press+ the seconds since
    # this tap went down, or nil between taps, and +alpha+ how much of it
    # shows. The shell draws it as the player's own hand: a fingertip, a
    # mouse pointer, or a gamepad's reticle and its A button.
    class GhostPose < Data.define(:x, :y, :press, :since_press, :alpha)
      # This pose +share+ of the way to +other+.
      def toward(other, share)
        GhostPose.new(x: x + ((other.x - x) * share), y: y + ((other.y - y) * share),
                      press: press + ((other.press - press) * share), since_press: other.since_press,
                      alpha: alpha + ((other.alpha - alpha) * share))
      end
    end

    # The ghost hand that shows the player what to do, without a word: it
    # taps a dot over and over (+mode+ :tap), waits beside one, holding
    # back (:hover), or fades away (:gone). +to+ is the dot's Anchor, and
    # since +at+ it glides there from where the hand was before
    # (+before+, the GhostHand it was), or fades in if it was nowhere.
    class GhostHand < Data.define(:mode, :to, :at, :before, :look)
      # One tap's loop: it comes in from rest, goes down, holds, comes up,
      # and goes back to rest, as fractions of the loop.
      ARRIVES = 0.25
      PRESSED = 0.34
      LIFTS = 0.44
      LIFTED = 0.53
      RESTS = 0.78

      def self.none(look) = new(mode: :gone, to: nil, at: -Float::INFINITY, before: nil, look:)

      def tapping(anchor, now) = moving(:tap, anchor, now)
      def hovering(anchor, now) = moving(:hover, anchor, now)
      def gone(now) = mode == :gone ? self : with(mode: :gone, to: nil, at: now, before: without_before)

      # Its pose at +now+ (GhostPose) among +dots+ of +radius+, or nil
      # where it shows nowhere.
      def pose(now, dots, radius)
        share = (now - at) / (mode == :gone ? look.fade : look.glide)
        earlier = before&.pose(now, dots, radius) if share < 1
        return earlier&.with(alpha: earlier.alpha * (1 - share)) if mode == :gone

        own = own_pose(now, dots, radius) or return
        return own if before && share >= 1
        return own.with(alpha: ((now - at) / look.fade).clamp(0.0, 1.0)) unless earlier

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
        elapsed = now - at - (before ? look.glide : 0.0)
        mode == :tap ? tap_pose(x, y, elapsed, radius) : hover_pose(x, y, elapsed, radius)
      end

      # Comes in from rest, presses, lifts, and goes back, over and over.
      def tap_pose(x, y, elapsed, radius)
        t = elapsed.negative? ? 0.0 : (elapsed % look.loop) / look.loop
        away = if t < ARRIVES then 1 - Ease.in_out_sine(t / ARRIVES)
               elsif t < LIFTED then 0.0
               elsif t < RESTS then Ease.in_out_sine((t - LIFTED) / (RESTS - LIFTED))
               else 1.0
               end
        rest_x, rest_y = look.rest
        GhostPose.new(x: x + (rest_x * radius * away), y: y + (rest_y * radius * away), press: press_at(t),
                      since_press: t >= ARRIVES && t < RESTS ? (t - ARRIVES) * look.loop : nil, alpha: 1.0)
      end

      def press_at(t)
        if t.between?(ARRIVES, PRESSED) then Ease.out_quad((t - ARRIVES) / (PRESSED - ARRIVES))
        elsif t.between?(PRESSED, LIFTS) then 1.0
        elsif t.between?(LIFTS, LIFTED) then 1 - Ease.in_quad((t - LIFTS) / (LIFTED - LIFTS))
        else 0.0
        end
      end

      # Beside the dot, never touching it, bobbing a little as it waits.
      def hover_pose(x, y, elapsed, radius)
        hover_x, hover_y = look.hover
        bob = Math.sin([elapsed, 0.0].max * 2 * Math::PI / look.loop) * look.bob
        GhostPose.new(x: x + (hover_x * radius), y: y + ((hover_y + bob) * radius), press: 0.0, since_press: nil,
                      alpha: 1.0)
      end
    end
  end
end
