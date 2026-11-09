# frozen_string_literal: true

module DotPopper
  module Presentation
    # How the dots fall into a pile once a game is over, when the rules
    # no longer move them and they are only scenery. Box2D (Shell::Pile)
    # does the falling; this says how it should feel, in radii and
    # seconds, so the pile looks alike at any dot size.
    #
    # +meter+ is how many radii make one of Box2D's meters, which it is
    # tuned for objects of about a meter; +gravity+ is in radii a second
    # squared; +restitution+, +friction+, and +density+ are each dot's;
    # +damping+ slows each dot in the air; +fling+ scales the velocity a
    # dot had when the game ended; and no step is longer than
    # +longest_step+, so a slow frame cannot tunnel a dot through a wall.
    class PileLook < Data.define(:meter, :gravity, :restitution, :friction, :density, :damping, :fling,
                                 :longest_step)
      # One of Box2D's meters, in graphics units, for a dot of +radius+.
      def meter_for(radius) = meter * radius

      # Gravity, in graphics units a second squared.
      def gravity_for(radius) = gravity * radius

      # How far to step the world for a frame of +seconds+.
      def step(seconds) = seconds.clamp(0.0, longest_step)

      # A dot's velocity as it joins the pile, in graphics units a second.
      def launch(dot) = [dot.velocity_x * fling, dot.velocity_y * fling]
    end

    # The walls the pile falls between: the window's floor and its two
    # sides, which rise as far again above the window, so the top is open
    # and a dot thrown upward comes back down. While the pile is tilted
    # (Tilt) it may fall any way, so a +lid+ along the window's top keeps
    # it on the screen. Each is a segment, as [x1, y1, x2, y2] in graphics
    # units.
    class PileWalls < Data.define(:width, :height, :lid)
      def initialize(width:, height:, lid: false) = super

      def segments
        sides = [[0.0, -height.to_f, 0.0, height.to_f],
                 [0.0, height.to_f, width.to_f, height.to_f],
                 [width.to_f, height.to_f, width.to_f, -height.to_f]]
        lid ? sides + [[0.0, 0.0, width.to_f, 0.0]] : sides
      end
    end
  end
end
