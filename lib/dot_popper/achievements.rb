# frozen_string_literal: true

module DotPopper
  # The Feats this device has earned, and the day each was first earned
  # (an ISO date), kept in a store that answers +read+ and +write(text)+,
  # as BestScore's does. They are earned and kept whether or not the
  # player has bought the paid version; only showing them waits for that.
  # Text it cannot read is left out, and a feat a newer version knows and
  # this one does not is dropped.
  class Achievements
    def initialize(store)
      @store = store
      @days = parse(store.read)
    end

    def earned?(id) = @days.key?(id)

    # The ids earned, in Feat::IDS order.
    def earned = Feat::IDS.select { earned?(it) }

    def count = @days.size

    # The day +id+ was earned, or nil.
    def day(id) = @days[id]

    # Keeps +ids+ as earned on +day+, saves, and returns those that were
    # not earned before, in Feat::IDS order.
    def award(ids, day:)
      fresh = Feat::IDS.select { ids.include?(it) && !earned?(it) }
      return fresh if fresh.empty?

      @days = @days.merge(fresh.to_h { [it, day.to_s] })
      @store.write(text)
      fresh
    end

    # The store's whole text, as saved, for #restore (RecordKeeper).
    def saved = @store.read

    # Forgets every feat, as on a new device.
    def clear
      @days = {}
      @store.write("")
    end

    # Puts back +text+, the store's whole text as #saved gave it.
    def restore(text)
      @store.write(text.to_s)
      @days = parse(text)
    end

    private

    def text = Feat::IDS.filter_map { |id| "#{id}=#{@days[id]}\n" if earned?(id) }.join

    def parse(text)
      text.to_s.lines.filter_map do |line|
        name, day = line.strip.split("=", 2)
        id = name&.to_sym
        [id, day.to_s] if id && Feat.known?(id)
      end.to_h
    end
  end
end
