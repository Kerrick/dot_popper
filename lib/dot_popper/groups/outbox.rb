# frozen_string_literal: true

module DotPopper
  module Groups
    # What this device owes the server: the score of a game that counts,
    # and the keys of achievements a Pro player has earned, until the
    # server has taken them. Each is sent only to a member of a group, so
    # a player who has not created or joined one sends nothing, and each is
    # in flight at most once at a time.
    #
    # Only the highest unsent score is kept: a lower game never replaces
    # it, and it does not expire. It is taken only by the answer to that
    # very score, so a higher one that arrives meanwhile still waits. A
    # score or a key the server will never take is dropped, and so is the
    # score once the player is in no group.
    class Outbox
      # The highest score the server takes.
      HIGHEST_SCORE = 100_000

      attr_reader :score, :achievements

      def initialize(score: nil, achievements: [])
        @score = score
        @achievements = achievements
        @score_in_flight = false
        @achievements_in_flight = []
      end

      # A game just ended: if it counts (played by a +member+, +counts+ as
      # the game says, which the tutorial's does not, and scoring), answers
      # its score as the server will take it, keeping the higher of it and
      # any that waits. Answers nil for a game that does not count.
      def owe_game(score:, counts:, member:)
        return unless member && counts == true && score.positive?

        score = score.clamp(0, HIGHEST_SCORE)
        @score = [score, @score.to_i].max
        score
      end

      # Achievement +keys+ to send; answers whether any was new.
      def owe_achievements(keys)
        new_keys = keys.map(&:to_s) - @achievements
        @achievements |= new_keys
        !new_keys.empty?
      end

      # The score to send now to a +member+, or nil: none waits, one is
      # already in flight, or the player is in no group.
      def take_score(member:)
        return unless @score && member && !@score_in_flight

        @score_in_flight = true
        @score
      end

      # The keys to send now to a +member+: those not already in flight.
      def take_achievements(member:)
        return [] unless member

        keys = @achievements - @achievements_in_flight
        @achievements_in_flight.concat(keys)
        keys
      end

      # A score sent has been answered, however it went.
      def score_settled = @score_in_flight = false

      # The server took +score+: it is owed no longer, unless a higher
      # one has come to wait since.
      def score_taken(score)
        @score = nil if @score == score
      end

      # The score waiting is dropped: the server will never take it, or
      # the player is in no group to send it to.
      def drop_score = @score = nil

      # A key sent has been answered, however it went.
      def achievement_settled(key) = @achievements_in_flight.delete(key)

      # The server took +key+, or will never take it.
      def drop_achievement(key) = @achievements.delete(key)

      # The player is forgotten: nothing is owed. A score in flight stays
      # in flight until its answer comes.
      def forget
        @score = nil
        @achievements = []
        @achievements_in_flight = []
      end
    end
  end
end
