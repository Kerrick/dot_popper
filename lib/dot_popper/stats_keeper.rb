# frozen_string_literal: true

module DotPopper
  # Clears the player's Stats, and brings them back: the ScoreRecord and
  # the StatsBook, the two stores that hold every record, total, chart bar,
  # and goal streak, and the Achievements, the achievements earned, which are
  # part of what the player did as much as a record is. Nothing else is
  # cleared, so the games log, the settings, what the game has taught,
  # and whether Pro was bought stay as they are.
  #
  # Clearing copies each store's text, exactly, to a backup named for
  # when it happened (score_record-20261105-093000.txt), through +folder+,
  # which gives the store of a name, as GamesLog's +archive+ does, and
  # stores there answer +remove+ too. NOTE lists the latest backups, and
  # the next clearing removes them, so the folder only ever keeps one.
  # Lota's save folder cannot rename a file, so nothing is moved: the
  # copies are written, then the stores are emptied.
  class StatsKeeper
    NOTE = "cleared.txt"
    BACKUP = /\A(?:score_record|stats|achievements)-\d{8}-\d{6}\.txt\z/

    def initialize(score_record:, stats_book:, achievements: nil, folder: Folder.new, clock: -> { Time.now })
      @kept = { "score_record" => score_record, "stats" => stats_book, "achievements" => achievements }.compact
      @folder = folder
      @clock = clock
      @cleared = !folder.call(NOTE).read.to_s.empty?
    end

    # Whether this device's Stats have ever been cleared, so the player
    # has played before, though their Stats say nothing yet.
    def cleared? = @cleared

    # Backs Stats up, then clears them, and returns them as Cleared,
    # for #restore.
    def clear
      texts = @kept.transform_values(&:saved)
      back_up(texts)
      @kept.each_value(&:clear)
      @cleared = true
      Cleared.new(texts:)
    end

    # Puts back Stats as they were before +cleared+ (Cleared). The
    # backup stays.
    def restore(cleared) = cleared.texts.each { |name, text| @kept.fetch(name).restore(text) }

    # The stores' texts as they were, by the name of each store.
    class Cleared < Data.define(:texts); end

    # Stores in memory by name, for tests and for a game with no save
    # folder.
    class Folder
      def initialize = @stores = {}
      def call(name) = @stores[name] ||= ScoreRecord::Memory.new
    end

    private

    def back_up(texts)
      note = @folder.call(NOTE)
      note.read.to_s.lines.filter_map { it.strip.split("=", 2).last }.grep(BACKUP).each { @folder.call(it).remove }
      time = @clock.call
      stamp = time.strftime("%Y%m%d-%H%M%S")
      saved = texts.filter_map do |name, text|
        next unless text

        file = "#{name}-#{stamp}.txt"
        @folder.call(file).write(text)
        "#{name}.txt=#{file}\n"
      end
      note.write("cleared=#{time.iso8601}\n#{saved.join}")
    end
  end
end
