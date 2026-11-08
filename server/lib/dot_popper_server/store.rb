# frozen_string_literal: true

require "digest"
require "securerandom"
require "sqlite3"

module DotPopperServer
  # Everything the server keeps, in one SQLite file: players by a hash of
  # their token, their one group each, the groups' trophies, thefts not
  # yet told, blocks, and reports. A player's deletion takes all of it
  # with them. SQLite takes one writer at a time, and the monitor keeps a
  # connection's transactions from interleaving across threads.
  class Store
    MAX_MEMBERS = 8
    CODE_LETTERS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    CODE_LENGTH = 6
    JOIN_TRIES_AN_HOUR = 20
    REPORTS_TO_HIDE = 2
    SECONDS_AN_HOUR = 3600

    SCHEMA = <<~SQL
      CREATE TABLE IF NOT EXISTS players (
        id INTEGER PRIMARY KEY, token_hash TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
        name_hidden INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS groups (
        id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE, holder_id INTEGER REFERENCES players(id) ON DELETE SET NULL,
        score INTEGER NOT NULL DEFAULT 0, day INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS members (
        player_id INTEGER PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
        group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE
      );
      CREATE TABLE IF NOT EXISTS thefts (
        id INTEGER PRIMARY KEY, group_id INTEGER NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        thief_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        victim_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE, score INTEGER NOT NULL,
        seen INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS blocks (
        blocker_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        blocked_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        PRIMARY KEY (blocker_id, blocked_id)
      );
      CREATE TABLE IF NOT EXISTS reports (
        reporter_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        reported_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
        name TEXT NOT NULL, at INTEGER NOT NULL, handled INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (reporter_id, reported_id)
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

    def create_player(name)
      token = SecureRandom.hex(32)
      @lock.synchronize do
        @db.execute("INSERT INTO players (token_hash, name, created_at) VALUES (?, ?, ?)",
                    [hash_of(token), name, @clock.call.to_i])
        { id: @db.last_insert_row_id, token: }
      end
    end

    # The player whose token this is, or nil.
    def player(token)
      return unless token

      @lock.synchronize { @db.get_first_row("SELECT * FROM players WHERE token_hash = ?", [hash_of(token)]) }
    end

    def rename(player_id, name) = write("UPDATE players SET name = ? WHERE id = ?", [name, player_id])

    # Deletes the player and everything about them: their membership,
    # thefts they took part in, blocks, and reports by or about them. A
    # trophy they held falls vacant, and a group left with nobody goes.
    def delete_player(player_id)
      transaction do
        group_id = group_id_of(player_id)
        @db.execute("DELETE FROM players WHERE id = ?", [player_id])
        delete_if_empty(group_id)
      end
    end

    def create_group(player_id)
      transaction do
        refuse!("already_in_group", 409) if group_id_of(player_id)
        @db.execute("INSERT INTO groups (code) VALUES (?)", [fresh_code])
        @db.execute("INSERT INTO members (player_id, group_id) VALUES (?, ?)", [player_id, @db.last_insert_row_id])
        view(player_id)
      end
    end

    # A try counts whether or not the code turns out right, so it is
    # written before the transaction that a wrong code rolls back.
    def join_group(player_id, code)
      @lock.synchronize { limit_tries(player_id) }
      transaction do
        refuse!("already_in_group", 409) if group_id_of(player_id)
        group = @db.get_first_row("SELECT id FROM groups WHERE code = ?", [normalize_code(code)])
        refuse!("no_such_group", 404) unless group
        refuse!("group_full", 409) if count_members(group["id"]) >= MAX_MEMBERS
        @db.execute("INSERT INTO members (player_id, group_id) VALUES (?, ?)", [player_id, group["id"]])
        view(player_id)
      end
    end

    # Leaving keeps the player's name for any other device but takes them
    # out of the group, gives up a trophy they held, and forgets any
    # thefts told to or by them there.
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
        blocked = blocked_by(player_id)
        members = @db.execute(<<~SQL, [group_id]).map { member_view(it, trophy, blocked, player_id) }
          SELECT players.* FROM players JOIN members ON members.player_id = players.id
          WHERE members.group_id = ? ORDER BY players.id
        SQL
        { code: group["code"], members:, trophy: trophy_view(trophy, members), news: news_for(player_id, blocked) }
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

    def block(blocker_id, blocked_id)
      with_member(blocker_id, blocked_id) do
        @db.execute("INSERT OR IGNORE INTO blocks (blocker_id, blocked_id) VALUES (?, ?)", [blocker_id, blocked_id])
      end
    end

    def unblock(blocker_id, blocked_id)
      write("DELETE FROM blocks WHERE blocker_id = ? AND blocked_id = ?", [blocker_id, blocked_id])
    end

    # Records a report of a member's name and blocks them for the reporter
    # at once. Reports from REPORTS_TO_HIDE people hide the name from
    # everyone straight away, so an offensive name goes before anyone has
    # to look at the queue; see #reports and bin/moderate.
    def report(reporter_id, reported_id)
      with_member(reporter_id, reported_id) do
        name = @db.get_first_value("SELECT name FROM players WHERE id = ?", [reported_id])
        @db.execute("INSERT OR IGNORE INTO reports (reporter_id, reported_id, name, at) VALUES (?, ?, ?, ?)",
                    [reporter_id, reported_id, name, @clock.call.to_i])
        @db.execute("INSERT OR IGNORE INTO blocks (blocker_id, blocked_id) VALUES (?, ?)", [reporter_id, reported_id])
        count = @db.get_first_value("SELECT COUNT(*) FROM reports WHERE reported_id = ? AND handled = 0", [reported_id])
        @db.execute("UPDATE players SET name_hidden = 1 WHERE id = ?", [reported_id]) if count >= REPORTS_TO_HIDE
      end
    end

    # The reports nobody has handled yet, oldest first.
    def reports
      @lock.synchronize do
        @db.execute("SELECT reported_id, name, COUNT(*) AS reports, MIN(at) AS first_at FROM reports " \
                    "WHERE handled = 0 GROUP BY reported_id ORDER BY first_at")
      end
    end

    # A moderator's answer to a report: +hide+ takes the name away from
    # everyone, and leaving it marks the reports handled.
    def handle_report(reported_id, hide:)
      transaction do
        @db.execute("UPDATE players SET name_hidden = ? WHERE id = ?", [hide ? 1 : 0, reported_id])
        @db.execute("UPDATE reports SET handled = 1 WHERE reported_id = ?", [reported_id])
      end
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

    def with_member(player_id, other_id)
      transaction do
        group_id = group_id_of(player_id)
        refuse!("not_in_group", 404) unless group_id && group_id == group_id_of(other_id) && player_id != other_id
        yield
      end
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
        code = Array.new(CODE_LENGTH) { CODE_LETTERS[SecureRandom.random_number(CODE_LETTERS.size)] }.join
        return code unless @db.get_first_value("SELECT 1 FROM groups WHERE code = ?", [code])
      end
    end

    def normalize_code(code) = code.to_s.upcase.gsub(/[^A-Z0-9]/, "")

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

    def blocked_by(player_id)
      @db.execute("SELECT blocked_id FROM blocks WHERE blocker_id = ?", [player_id]).map { it["blocked_id"] }
    end

    def shown_name(row, blocked)
      return "Someone" if blocked.include?(row["id"])
      return "Player #{row["id"] % 1000}" if row["name_hidden"] == 1

      row["name"]
    end

    def member_view(row, trophy, blocked, viewer)
      { id: row["id"], name: shown_name(row, blocked), holder: row["id"] == trophy.holder,
        blocked: blocked.include?(row["id"]), me: row["id"] == viewer }
    end

    def trophy_view(trophy, members)
      holder = members.find { it[:holder] }
      { holder_id: trophy.holder, holder_name: holder && holder[:name], score: trophy.score,
        standing: trophy.standing(today), days_held: trophy.days_held(today) }
    end

    # The thefts not yet told to +player_id+, by anyone they have not
    # blocked: one message per theft, and only to the one it was taken
    # from.
    def news_for(player_id, blocked)
      rows = @db.execute(<<~SQL, [player_id])
        SELECT thefts.id, thefts.score, thefts.thief_id, players.name, players.name_hidden, players.id AS pid
        FROM thefts JOIN players ON players.id = thefts.thief_id
        WHERE thefts.victim_id = ? AND thefts.seen = 0 ORDER BY thefts.id
      SQL
      rows.reject { blocked.include?(it["thief_id"]) }.map do |row|
        { id: row["id"], thief: shown_name({ "id" => row["pid"], "name" => row["name"], "name_hidden" => row["name_hidden"] }, blocked),
          score: row["score"] }
      end
    end
  end
end
