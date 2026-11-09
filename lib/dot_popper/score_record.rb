# frozen_string_literal: true

module DotPopper
  # The highest score on this device, kept for each SizeClass, since a
  # phone's best and a big monitor's are different contests. It reads and
  # writes through a store that answers +read+ and +write(text)+, so the
  # rules never touch a file system themselves (Lota's save folder in the
  # game, memory in tests). It saves as lines of +class=score+.
  #
  # A store written before scores were kept by class holds one bare
  # number. That best belongs to +legacy+, the class of the screen the
  # game opens on, and is saved again in the new form at once, so it
  # stays there whichever screen the game opens on next.
  class ScoreRecord
    def initialize(store, legacy: SizeClass::MEDIUM)
      @store = store
      @legacy = legacy
      text = store.read.to_s
      @values = Table.parse(text, legacy:)
      save if Table.old?(text)
    end

    # The best score on screens of +size_class+, or 0 before there is one.
    def of(size_class) = @values.fetch(size_class, 0)

    # Whether no game has been recorded on screens of +size_class+ yet.
    def first?(size_class) = !@values.key?(size_class)

    # Records +score+ as one played on +size_class+, and says whether it
    # beat that class's best. A class's first game sets its best but
    # beats nothing, so it is never a new record: there was nothing to beat.
    def record(score, size_class)
      first = first?(size_class)
      return false unless first || score > of(size_class)

      @values = @values.merge(size_class => score)
      save
      !first
    end

    # The store's whole text, as saved, for #restore (RecordKeeper).
    def saved = @store.read

    # Forgets every class's best, as on a new device.
    def clear
      @values = {}
      @store.write("")
    end

    # Puts back +text+, the store's whole text as #saved gave it.
    def restore(text)
      @store.write(text.to_s)
      @values = Table.parse(text.to_s, legacy: @legacy)
    end

    private

    def save = @store.write(Table.to_text(@values))

    # How a store's text reads and writes.
    module Table
      OLD = /\A\s*\d+\s*\z/

      # Each class's score, read leniently: a line that is not
      # +class=score+ for a known class, with a whole number, is skipped.
      def self.parse(text, legacy:)
        return { legacy => Integer(text.strip, 10) } if old?(text)

        text.lines.filter_map do |line|
          name, score = line.strip.split("=", 2)
          size_class = SizeClass.named(name.to_s)
          number = Integer(score.to_s, 10, exception: false)
          [size_class, number] if size_class && number && !number.negative?
        end.to_h
      end

      # Whether +text+ is the single number written before classes.
      def self.old?(text) = OLD.match?(text)

      def self.to_text(values) = values.map { |size_class, score| "#{size_class.name}=#{score}\n" }.join
    end

    # A store that keeps the score in memory, for tests and for a device
    # whose save folder cannot be written.
    class Memory
      def initialize(text = nil) = @text = text
      def read = @text
      def write(text) = @text = text
      def remove = @text = nil
    end
  end
end
