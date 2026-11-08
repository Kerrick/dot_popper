# frozen_string_literal: true

module DotPopper
  # Clears the player's records, and brings them back: the BestScore and
  # the Lifetime, the two stores that hold every best, total, chart bar,
  # and goal streak, and the Achievements, the feats earned, which are
  # records of what the player did as much as a best is. Nothing else is
  # a record, so the playtest log, the settings, what the game has taught,
  # and whether the paid version was bought stay as they are.
  #
  # Clearing copies each store's text, exactly, to a backup named for
  # when it happened (best_score-20261105-093000.txt), through +folder+,
  # which gives the store of a name, as PlaytestLog's +archive+ does, and
  # stores there answer +remove+ too. NOTE lists the latest backups, and
  # the next clearing removes them, so the folder only ever keeps one.
  # Lota's save folder cannot rename a file, so nothing is moved: the
  # copies are written, then the stores are emptied.
  class RecordKeeper
    NOTE = "cleared.txt"
    BACKUP = /\A(?:best_score|lifetime|achievements)-\d{8}-\d{6}\.txt\z/

    def initialize(best:, lifetime:, achievements: nil, folder: Folder.new, clock: -> { Time.now })
      @kept = { "best_score" => best, "lifetime" => lifetime, "achievements" => achievements }.compact
      @folder = folder
      @clock = clock
      @cleared = !folder.call(NOTE).read.to_s.empty?
    end

    # Whether this device's records have ever been cleared, so the player
    # has played before, though their records say nothing yet.
    def cleared? = @cleared

    # Backs the records up, then clears them, and returns them as Cleared,
    # for #restore.
    def clear
      texts = @kept.transform_values(&:saved)
      back_up(texts)
      @kept.each_value(&:clear)
      @cleared = true
      Cleared.new(texts:)
    end

    # Puts back the records as they were before +cleared+ (Cleared). The
    # backup stays.
    def restore(cleared) = cleared.texts.each { |name, text| @kept.fetch(name).restore(text) }

    # The records' texts as they were, by the name of their store.
    class Cleared < Data.define(:texts); end

    # Stores in memory by name, for tests and for a game with no save
    # folder.
    class Folder
      def initialize = @stores = {}
      def call(name) = @stores[name] ||= BestScore::Memory.new
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
