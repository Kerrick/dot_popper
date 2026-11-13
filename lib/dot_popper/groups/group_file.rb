# frozen_string_literal: true

module DotPopper
  module Groups
    # What this device remembers of a group's title: the newest change it
    # has shown, and how the group looked when it read the history.
    Seen = Data.define(:last, :fingerprint)

    # What group.txt holds (or group-<host>.txt, for another server), one
    # line each: the player's +token+, the +unsent_score+, whether the
    # player was last known to be a +member+ of a group ("1", or empty),
    # what has been +seen+ of each group's title ("id|last|fingerprint",
    # separated by spaces), and the +unsent_achievements+' keys (separated
    # by commas). Read leniently: a line missing or unreadable keeps its
    # starting value, so a file from a build that wrote four lines, before
    # achievements were sent, is read too.
    class GroupFile < Data.define(:token, :unsent_score, :member, :seen, :unsent_achievements)
      def self.parse(text)
        token, score, member, seen, unsent = text.to_s.split("\n", -1)
        new(token: token.to_s.empty? ? nil : token, unsent_score: Integer(score.to_s, 10, exception: false), member: member == "1",
            seen: parse_seen(seen.to_s), unsent_achievements: unsent.to_s.split(","))
      end

      def self.parse_seen(line)
        line.split.to_h do |entry|
          id, last, fingerprint = entry.split("|", 3)
          [Integer(id.to_s, 10, exception: false) || id.to_s, Seen.new(last: last.to_i, fingerprint:)]
        end
      end

      private_class_method :parse_seen

      def to_s
        seen_line = seen.map { |id, entry| "#{id}|#{entry.last}|#{entry.fingerprint}" }.join(" ")
        [token.to_s, unsent_score.to_s, member ? "1" : "", seen_line, unsent_achievements.join(",")].join("\n")
      end
    end
  end
end
