# frozen_string_literal: true

module DotPopper
  module Groups
    # One member of a group, by the number the server gave them. A number
    # is the only identity a player has: no name and nothing a player
    # supplies, so there is nothing to filter, report or block. The game
    # draws it (Presentation::MemberIcon).
    class Member < Data.define(:number, :top_score)
      def self.parse(data)
        return unless data.is_a?(Hash) && data["number"].is_a?(Integer)

        new(number: data["number"], top_score: data["top_score"].to_i)
      end
    end

    # A group as the server describes it. Parsing answers nil for anything
    # else, so a surprising reply is quietly ignored.
    class Group < Data.define(:id, :join_code, :you, :members, :champion_number, :top_score, :reign_started_at)
      ID = /\A[\w-]+\z/

      def self.id?(value) = value.is_a?(Integer) || (value.is_a?(String) && value.match?(ID))

      def self.parse(data)
        return unless data.is_a?(Hash) && id?(data["id"]) && data["you"].is_a?(Integer) && data["members"].is_a?(Array)
        return unless data["join_code"].is_a?(String) && (data["champion_number"].nil? || data["champion_number"].is_a?(Integer))

        new(id: data["id"], join_code: data["join_code"], you: data["you"], members: data["members"].filter_map { Member.parse(it) },
            champion_number: data["champion_number"], top_score: data["top_score"].to_i, reign_started_at: data["reign_started_at"])
      end

      def champion? = champion_number == you
      def vacant? = champion_number.nil?

      # The members, best first, the champion leading a tie.
      def standings = members.sort_by { [it.number == champion_number ? 0 : 1, -it.top_score, it.number] }

      # What a change in the group's title looks like from outside, so that
      # the title's history is only fetched once it has moved.
      def fingerprint = "#{champion_number}~#{top_score}"

      # The score that would win the title, which must be strictly higher.
      def score_to_win = top_score + 1
    end

    # One entry in a group's history of its title. +previous_champion_number+
    # is nil when the title was vacant: a group's first champion, or the
    # first after a vacancy. +passed_on+ is true when the title passed to
    # this champion because the previous one left, false when they won it,
    # and nil when the server does not say.
    class TitleChange < Data.define(:id, :champion_number, :previous_champion_number, :score, :at, :passed_on)
      def initialize(id:, champion_number:, previous_champion_number:, score:, at:, passed_on: nil)
        super
      end

      def self.parse(data)
        return unless data.is_a?(Hash) && data["id"].is_a?(Integer) && data["champion_number"].is_a?(Integer)
        return unless data["kind"].nil? || data["kind"] == "title_change"

        new(id: data["id"], champion_number: data["champion_number"], previous_champion_number: data["previous_champion_number"],
            score: data["score"].to_i, at: data["at"], passed_on: data["passed_on"] == true || data["passed_on"] == false ? data["passed_on"] : nil)
      end
    end

    # A member earning an achievement, as it appears in a group's history.
    # The +key+ is an Achievement's id; a key this game does not know is
    # kept out of what is shown (Presentation::GroupScreen).
    class MemberAchievement < Data.define(:id, :member_number, :key, :at)
      def self.parse(data)
        return unless data.is_a?(Hash) && data["kind"] == "achievement" && data["id"].is_a?(Integer) && data["member_number"].is_a?(Integer)

        new(id: data["id"], member_number: data["member_number"], key: data["key"].to_s.to_sym, at: data["at"])
      end
    end

    # Something to tell the player about a group's title, once, with no
    # answer asked of them. +kind+ is :you_won, :you_lost (someone took it
    # from this player) or :changed (it passed between others). A title
    # that passed because its champion left is :passed_to_you or :passed.
    class Announcement < Data.define(:group_id, :champion_number, :score, :kind)
      def self.of(group, change)
        new(group_id: group.id, champion_number: change.champion_number, score: change.score, kind: kind_of(group, change))
      end

      def self.kind_of(group, change)
        if change.passed_on
          return change.champion_number == group.you ? :passed_to_you : :passed
        end
        return :you_won if change.champion_number == group.you

        change.previous_champion_number == group.you ? :you_lost : :changed
      end
    end

    # What one game did across the player's groups, for Game Over: how many
    # titles it +won+ and how many it +raised+ (a champion beat their own
    # score), and the fewest points short of a title it fell (+short+, nil
    # if it was not short of any). +reigning+ is true when the player
    # already holds every title it could have won. +taken+ are the ids of
    # the groups whose titles it won, so Game Over can name and open one.
    class GameResult < Data.define(:won, :raised, :short, :reigning, :taken)
      def initialize(won:, raised:, short:, reigning:, taken: []) = super
    end
  end
end
