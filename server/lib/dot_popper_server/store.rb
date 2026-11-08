# frozen_string_literal: true

require "digest"
require "securerandom"
require "sqlite3"

module DotPopperServer
  # Everything the server keeps, in one SQLite file: players by a hash of
  # their token, their one group each and the mark they wear in it, the
  # groups' trophies, and thefts not yet told. There is no name, no text,
  # nothing a player supplies: a member is only a mark, chosen from
  # DotPopper::Groups::Mark. A player's deletion takes all of it with them.
  # SQLite takes one writer at a time, and the monitor keeps a
  # connection's transactions from interleaving across threads.
  class Store
    MAX_MEMBERS = DotPopper::Groups::Mark::COUNT
    CODE_DIGITS = "0123456789"
    CODE_LENGTH = 7
    JOIN_TRIES_AN_HOUR = 20
    SECONDS_AN_HOUR = 3600

    SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY, token_hash TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS groups (
        id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE, holder_id INTEGER REFERENCES players(id) ON DELETE SET NULL,
        score INTEGER NOT NULL DEFAULT 0, day INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS members (
        player_id INTEGER PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
        group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        mark INTEGER NOT NULL, UNIQUE (group_id, mark)
      );
      CREATE TABLE IF NOT EXISTS thefts (
        id INTEGER PRIMARY KEY, group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        thief_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        victim_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE, score INTEGER NOT NULL,
        seen INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS join_tries (player_id INTEGER NOT NULL, at INTEGER NOT NULL);
      CREATE INDEX IF NOT EXISTS join_tries_by_player ON join_tries (player_id, at);
    SQL

    # A reason a request failed, which the App turns into a status.
    class Refused < StandardError
      attr_reader :status

      def initialize(reason, status)
        super(reason)
        @status = status
      end
    end

    def initialize(path, clock: -> { Time.now })
      @clock = clock
      @lock = Monitor.new
      @db = SQLite3::Database.new(path)
      @db.results_as_hash = true
      @db.busy_timeout = 2000
      @db.execute("PRAGMA journal_mode=WAL")
      @db.execute("PRAGMA foreign_keys=ON")
      @db.execute_batch(SCHEMA)
    end

    def today = DotPopper::Trophy.day(@clock.call)

    def create_player
      token = SecureRandom.hex(32)
      @lock.synchronize do
        @db.execute("INSERT INTO players (token_hash, created_at) VALUES (?, ?)", [hash_of(token), @clock.call.to_i])
        { id: @db.last_insert_row_id, token: }
      end
    end

    # The player whose token this is, or nil.
    def player(token)
      return unless token

      @lock.synchronize { @db.get_first_row("SELECT * FROM players WHERE token_hash = ?", [hash_of(token)]) }
    end

    # Deletes the player and everything about them: their membership and
    # the thefts they took part in. A trophy they held falls vacant, and a
    # group left with nobody goes.
    def delete_player(player_id)
      transaction do
        group_id = group_id_of(player_id)
        @db.execute("DELETE FROM players WHERE id = ?", [player_id])
        delete_if_empty(group_id)
      end
    end

    # A new group with this player in it, wearing +mark+ (any member's
    # first is free, so it is theirs if it is a mark at all).
    def create_group(player_id, mark = nil)
      transaction do
        refuse!("already_in_group", 409) if group_id_of(player_id)
        @db.execute("INSERT INTO groups (code) VALUES (?)", [fresh_code])
        add_member(player_id, @db.last_insert_row_id, mark)
        view(player_id)
      end
    end

    # A try counts whether or not the code turns out right, so it is
    # written before the transaction that a wrong code rolls back. The
    # player wears +mark+ if no one in the group does, or else the first
    # mark that is free.
    def join_group(player_id, code, mark = nil)
      @lock.synchronize { limit_tries(player_id) }
      transaction do
        refuse!("already_in_group", 409) if group_id_of(player_id)
        group = @db.get_first_row("SELECT id FROM groups WHERE code = ?", [normalize_code(code)])
        refuse!("no_such_group", 404) unless group
        refuse!("group_full", 409) if count_members(group["id"]) >= MAX_MEMBERS
        add_member(player_id, group["id"], mark)
        view(player_id)
      end
    end

    # Leaving takes the player out of the group, gives up a trophy they
    # held, and forgets any thefts told to or by them there.
    def leave_group(player_id)
      transaction do
        group_id = group_id_of(player_id) or refuse!("not_in_group", 404)
        @db.execute("DELETE FROM members WHERE player_id = ?", [player_id])
        @db.execute("UPDATE groups SET holder_id = NULL, score = 0, day = 0 WHERE id = ? AND holder_id = ?",
                    [group_id, player_id])
        @db.execute("DELETE FROM thefts WHERE group_id = ? AND (thief_id = ? OR victim_id = ?)",
                    [group_id, player_id, player_id])
        delete_if_empty(group_id)
      end
    end

    # The group as +player_id+ sees it, or nil when they are in none.
    def view(player_id)
      @lock.synchronize do
        group_id = group_id_of(player_id) or return nil
        group = @db.get_first_row("SELECT * FROM groups WHERE id = ?", [group_id])
        trophy = trophy_of(group)
        members = @db.execute(<<~SQL, [group_id]).map { member_view(it, trophy, player_id) }
          SELECT players.id, members.mark FROM players JOIN members ON members.player_id = players.id
          WHERE members.group_id = ? ORDER BY members.mark
        SQL
        { code: group["code"], members:, trophy: trophy_view(trophy, members), news: news_for(player_id) }
      end
    end

    # Reports a round's +score+, and returns whether it took the trophy
    # and the group as it stands after. Only the server's day counts.
    def report_round(player_id, score)
      transaction do
        group_id = group_id_of(player_id) or refuse!("not_in_group", 404)
        group = @db.get_first_row("SELECT * FROM groups WHERE id = ?", [group_id])
        trophy = trophy_of(group)
        taken = trophy.beaten_by?(player_id, score, today)
        take(group_id, trophy, player_id, score) if taken
        { taken:, group: view(player_id) }
      end
    end

    # Marks thefts told to +player_id+ as told, so each is told once.
    def mark_seen(player_id, ids)
      return if ids.empty?

      marks = (["?"] * ids.size).join(", ")
      write("UPDATE thefts SET seen = 1 WHERE victim_id = ? AND id IN (#{marks})", [player_id, *ids])
    end

    private

    def hash_of(token) = Digest::SHA256.hexdigest(token)

    def write(sql, binds) = @lock.synchronize { @db.execute(sql, binds) }

    def transaction
      @lock.synchronize { @db.transaction(:immediate) { yield } }
    end

    def group_id_of(player_id)
      @db.get_first_value("SELECT group_id FROM members WHERE player_id = ?", [player_id])
    end

    def count_members(group_id) = @db.get_first_value("SELECT COUNT(*) FROM members WHERE group_id = ?", [group_id])

    def delete_if_empty(group_id)
      return unless group_id && count_members(group_id).zero?

      @db.execute("DELETE FROM groups WHERE id = ?", [group_id])
    end

    def refuse!(reason, status) = raise(Refused.new(reason, status))

    def add_member(player_id, group_id, wanted)
      @db.execute("INSERT INTO members (player_id, group_id, mark) VALUES (?, ?, ?)",
                  [player_id, group_id, mark_for(group_id, wanted)])
    end

    # +wanted+ if it is a mark and no one in the group wears it, else the
    # first mark that is free. Anything that is not a mark is refused,
    # never kept or shown.
    def mark_for(group_id, wanted)
      refuse!("bad_mark", 422) unless wanted.nil? || DotPopper::Groups::Mark.valid?(wanted)
      taken = @db.execute("SELECT mark FROM members WHERE group_id = ?", [group_id]).map { it["mark"] }
      return wanted if wanted && !taken.include?(wanted)

      DotPopper::Groups::Mark.free(taken) or refuse!("group_full", 409)
    end

    def limit_tries(player_id)
      now = @clock.call.to_i
      @db.execute("DELETE FROM join_tries WHERE at < ?", [now - SECONDS_AN_HOUR])
      tries = @db.get_first_value("SELECT COUNT(*) FROM join_tries WHERE player_id = ?", [player_id])
      refuse!("too_many_tries", 429) if tries >= JOIN_TRIES_AN_HOUR
      @db.execute("INSERT INTO join_tries (player_id, at) VALUES (?, ?)", [player_id, now])
    end

    def fresh_code
      loop do
        code = Array.new(CODE_LENGTH) { CODE_DIGITS[SecureRandom.random_number(CODE_DIGITS.size)] }.join
        return code unless @db.get_first_value("SELECT 1 FROM groups WHERE code = ?", [code])
      end
    end

    def normalize_code(code) = code.to_s.gsub(/[^0-9]/, "")

    def trophy_of(group)
      return DotPopper::Trophy.vacant unless group["holder_id"]

      DotPopper::Trophy.new(holder: group["holder_id"], score: group["score"], day: group["day"])
    end

    def take(group_id, trophy, player_id, score)
      taken = trophy.taken_by(player_id, score, today)
      @db.execute("UPDATE groups SET holder_id = ?, score = ?, day = ? WHERE id = ?",
                  [taken.holder, taken.score, taken.day, group_id])
      return if trophy.vacant?

      @db.execute("INSERT INTO thefts (group_id, thief_id, victim_id, score) VALUES (?, ?, ?, ?)",
                  [group_id, player_id, trophy.holder, score])
    end

    def member_view(row, trophy, viewer)
      { mark: row["mark"], holder: row["id"] == trophy.holder, me: row["id"] == viewer }
    end

    def trophy_view(trophy, members)
      holder = members.find { it[:holder] }
      { holder_id: trophy.holder, holder_mark: holder && holder[:mark], score: trophy.score,
        standing: trophy.standing(today), days_held: trophy.days_held(today) }
    end

    # The thefts not yet told to +player_id+: one message per theft, and
    # only to the one it was taken from. The thief is known by their mark.
    def news_for(player_id)
      rows = @db.execute(<<~SQL, [player_id])
        SELECT thefts.id, thefts.score, members.mark
        FROM thefts JOIN members ON members.player_id = thefts.thief_id AND members.group_id = thefts.group_id
        WHERE thefts.victim_id = ? AND thefts.seen = 0 ORDER BY thefts.id
      SQL
      rows.map { { id: it["id"], thief: it["mark"], score: it["score"] } }
    end
  end
end
