# frozen_string_literal: true

module DotPopper
  module Groups
    # This device's copy of what the server last said of the player's
    # groups: the groups, each group's title changes and history, and
    # whether the player was last known to be in a group. The groups
    # themselves are the server's; what the server answers replaces what
    # is here, and the game decides only what to announce from it and when
    # a group's history is worth reading again.
    #
    # It also keeps, for each group, the newest title change already
    # shown and how the group looked when its history was read (Seen), so
    # a title change is announced once, from the history alone: a group
    # met for the first time announces nothing of its past, and only the
    # newest change in a group is told.
    class ReadModel
      attr_reader :groups, :seen, :last_known_member

      def initialize(last_known_member: false, seen: {})
        @last_known_member = last_known_member
        @seen = seen
        @groups = []
        @changes = {}
        @history = {}
        @announcements = []
        @arrival = nil
      end

      # Whether the player is in a group, as far as is known: after a
      # launch with no network the groups are unknown, but the last known
      # answer stands.
      def member? = !@groups.empty? || @last_known_member
      def group(id) = @groups.find { it.id == id }
      def title_changes(id) = @changes[id]
      def history(id) = @history[id]

      # The player's groups, all of them, as the server listed them.
      def replace(groups)
        @groups = groups
        @seen.select! { |id, _| group(id) }
      end

      # One group as the server described it, new or changed.
      def upsert(group)
        index = @groups.index { it.id == group.id }
        index ? @groups[index] = group : @groups << group
      end

      # A group the player is no longer in.
      def gone(id)
        @groups.reject! { it.id == id }
        @changes.delete(id)
        @history.delete(id)
        @seen.delete(id)
      end

      # Notes whether the player is in a group now; answers whether that
      # changed.
      def remember_membership
        member = !@groups.empty?
        changed = @last_known_member != member
        @last_known_member = member
        changed
      end

      # Whether +group+'s title looks different from when its history was
      # last read, so the history is worth reading again.
      def title_moved?(group) = @seen[group.id]&.fingerprint != group.fingerprint

      # A group's history as the server answered it. Answers whether it
      # was taken: only for a group the player is known to be in.
      def read_history(id, body)
        return false unless body.is_a?(Array) && (known_group = group(id))

        changes = body.filter_map { TitleChange.parse(it) }.sort_by { -it.id }
        @changes[id] = changes
        @history[id] = (changes + body.filter_map { MemberAchievement.parse(it) }).sort_by { -it.id }
        announce(known_group, changes)
        @seen[id] = Seen.new(last: [@seen[id]&.last.to_i, changes.first&.id.to_i].max, fingerprint: known_group.fingerprint)
        true
      end

      # The next title change to tell the player, once, or nil.
      def next_announcement = @announcements.shift

      # A group just created or joined, for a screen to open once.
      def arrived(id) = @arrival = id

      def take_arrival
        arrival = @arrival
        @arrival = nil
        arrival
      end

      # The player is forgotten, and with them everything heard.
      def forget
        @groups = []
        @changes = {}
        @history = {}
        @seen = {}
        @announcements.clear
        @last_known_member = false
      end

      private

      # Tells of the newest change the player has not been told of. A group
      # met for the first time has nothing new: what happened before is its
      # history.
      def announce(group, changes)
        seen = @seen[group.id] or return
        newest = changes.first
        return unless newest && newest.id > seen.last

        @announcements.reject! { it.group_id == group.id }
        @announcements << Announcement.of(group, newest)
      end
    end
  end
end
