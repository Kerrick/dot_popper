# frozen_string_literal: true

module DotPopper
  module Presentation
    # Game over, shown since +at+: the game dimming behind, the heading
    # arriving, the score counting up, and the prompt to go on, which
    # shows only from +ready_at+, once a press would be heard. A new best
    # is celebrated once, when it has finished counting. +stats+ are the
    # game's RoundStats, for the line of facts under the score. +record+
    # is the most impressive lifetime record the game set
    # (Stats::Record), or nil, and +goal_met+ whether it was the
    # first game to meet today's goal, which is celebrated once, also when
    # the score has counted. +screen+ says what screen the game was
    # played on, for the result to share (Words#played_on), or is nil.
    # +lesson+ is the wrong tap to teach the stacking rule from (Mistake,
    # from the Tutor), on the first Game Overs after a wrong tap with the
    # bright dot hidden beneath, or nil, and +replayed+ how many times it
    # has replayed.
    # +first+ says the game was the first of its SizeClass, which set the
    # best without beating one. +achievements+ are the ids of the achievements (Achievement)
    # the game earned for the first time, which a player who has the
    # paid version hears of in a line after the score, never during the
    # game.
    class Finale < Data.define(:look, :score, :best, :new_best, :at, :stats, :record, :goal_met, :ready_at,
                               :celebrated, :goal_celebrated, :screen, :lesson, :replayed, :first, :achievements)
      def initialize(look:, score:, best:, new_best:, at:, stats: GameStats.start, record: nil, goal_met: false,
                     ready_at: nil, celebrated: false, goal_celebrated: false, screen: nil, lesson: nil, replayed: 0, first: false,
                     achievements: [])
        super
      end

      def goal_due?(now) = goal_met && !goal_celebrated && counted?(now)
      def goal_celebrate = with(goal_celebrated: true)

      # How far the lines that follow the count, a record or the goal, have
      # faded in.
      def afterword(now) = counted?(now) ? look.prompt.at(now - at - look.tally.duration) : 0.0

      # How "Share my score" comes in (ShareCue), once the score lands.
      def share_cue(now) = ShareCue.at(now - at - look.tally.duration, look.share, best: new_best?)

      def new_best? = new_best

      def dim(now) = look.dim.at(now - at)
      def arrival(now) = look.arrive.at(now - at)

      def shown_score(now) = (score * look.tally.progress(now - at)).round
      def counted?(now) = look.tally.done?(now - at)

      # The finale once the game says it will take a press.
      def ready(now) = ready_at ? self : with(ready_at: now)
      def prompt(now) = ready_at ? look.prompt.at(now - ready_at) : 0.0

      def celebration_due?(now) = new_best? && !celebrated && counted?(now)
      def celebrate = with(celebrated: true)

      # The finale once its lesson has replayed once more.
      def replay = with(replayed: replayed + 1)
    end

    # How "Share my score" comes in (FinaleLook's +share+): it rises
    # +lift+ units into place along +arrive+, bouncing a little past it,
    # and as it settles a ring spreads out from its edge and fades,
    # +ring_reach+ units at most and +ring_alpha+ bright. On a new best it
    # waits +best_delay+ more, for the celebration, rises further, and
    # rings brighter and wider.
    class ShareCueLook < Data.define(:arrive, :lift, :best_lift, :best_delay, :ring, :ring_reach, :ring_alpha,
                                     :best_ring_reach, :best_ring_alpha); end

    # Where "Share my score" is in its arrival: how much of it shows
    # (+alpha+), how far below its place it is (+drop+, in units), and its
    # ring's distance out from the button's edge (+ring+, in units) and
    # opacity (+ring_alpha+, 0 for no ring).
    class ShareCue < Data.define(:alpha, :drop, :ring, :ring_alpha)
      # The cue +elapsed+ seconds after the score landed, negative before
      # then, by +look+ (ShareCueLook); +best+ for a new best.
      def self.at(elapsed, look, best: false)
        elapsed -= look.best_delay if best
        return new(alpha: 0.0, drop: 0.0, ring: 0.0, ring_alpha: 0.0) unless elapsed.positive?

        ringing = elapsed - (look.arrive.duration * 0.4)
        spread = look.ring.progress(ringing)
        new(alpha: (elapsed / (look.arrive.duration * 0.5)).clamp(0.0, 1.0),
            drop: (1 - look.arrive.progress(elapsed)) * (best ? look.best_lift : look.lift),
            ring: spread * (best ? look.best_ring_reach : look.ring_reach),
            ring_alpha: ringing.positive? ? (1 - spread) * (best ? look.best_ring_alpha : look.ring_alpha) : 0.0)
      end
    end
  end
end
