# frozen_string_literal: true

require_relative "../../dot_popper"

module DotPopper
  module Privacy
    # Why players needn't be told about something one by one: its +kind+
    # (a test build's, a developer's, a diagnostic) and the +reason+.
    class Aside < Data.define(:kind, :reason)
      KINDS = %i[test_only developer_only diagnostics].freeze

      def initialize(kind:, reason:)
        raise ArgumentError, "unknown kind #{kind}" unless KINDS.include?(kind)

        super
      end
    end

    # A file the game keeps in its save folder. +name+ is the name, or how
    # a dated name looks; +pattern+ matches a dated name (nil for a fixed
    # one). It must have either a +label+, the words a player reads, or an
    # +aside+ saying why they needn't. +sent+ names what in it also leaves
    # the device, as the Request field it goes in, in a player's words.
    class KeptFile < Data.define(:name, :pattern, :holds, :made_by, :label, :aside, :sent)
      def initialize(name:, holds:, pattern: nil, made_by: "the game", label: nil, aside: nil, sent: {})
        raise ArgumentError, "#{name} needs a label or an aside, not both" if label.nil? == aside.nil?

        super
      end

      def covers?(file) = pattern ? pattern.match?(file) : name == file
    end

    # Every file in the save folder, by Shell::SaveFile's refusal and
    # test/privacy/declared_test.rb.
    SAVE_FILES = [
      KeptFile.new(name: "score_record.txt", label: "Your best score", holds: "your best score for each dot size"),
      KeptFile.new(name: "stats.txt", label: "Your statistics", holds: "your statistics: totals, chart bars and goal streak"),
      KeptFile.new(name: "achievements.txt", label: "Your achievements", holds: "your achievements and the day each was earned"),
      KeptFile.new(name: "entitlement.txt", label: "Whether you bought Pro", holds: "whether Pro was bought"),
      KeptFile.new(name: "store_answer.txt", label: "Whether you bought Pro", made_by: "the iOS or Android host, read by the game", holds: "what the store last answered about Pro, and its price"),
      KeptFile.new(name: "themes.txt", label: "Your themes", holds: "your themes and which is chosen"),
      KeptFile.new(name: "started_on.txt", label: "The date you first played", holds: "the date you first played, sent to learn which themes are available"),
      KeptFile.new(name: "games.txt", label: "How many free games you have left", holds: "how many free games are left and used today"),
      KeptFile.new(name: "games.csv", label: "A history of your games", holds: "a history of your games: when, score, and how each went"),
      KeptFile.new(name: "games-YYYYMMDD-HHMMSS.csv", label: "A history of your games", pattern: /\Agames-\d{8}-\d{6}\.csv\z/, holds: "an older game history, kept whole when its columns changed"),
      KeptFile.new(name: "<record>-YYYYMMDD-HHMMSS.txt", label: "A copy of your records, if you clear them", pattern: StatsKeeper::BACKUP, holds: "a backup of your records from when you cleared them"),
      KeptFile.new(name: "dot_size.txt", label: "Your settings", holds: "your choice of dot size"),
      KeptFile.new(name: "sound.txt", label: "Your settings", holds: "your sound setting"),
      KeptFile.new(name: "taught.txt", label: "What the game has shown you", holds: "what the game has already shown you"),
      KeptFile.new(name: "tutorial.txt", label: "What the game has shown you", holds: "whether you have played the tutorial"),
      KeptFile.new(name: "group.txt", label: "Your private code and any unsent score, if you use friend groups",
                   holds: "your anonymous group token, an unsent score, whether you were in a group, the newest title change you were shown of each, and any achievements waiting to be sent",
                   sent: { token: "your private code", score: "your scores from games that count" }),
      KeptFile.new(name: "cleared.txt", aside: Aside.new(kind: :diagnostics, reason: "Only the names of the backups to replace next time."), holds: "the names of the backups made by the last clearing of your records"),
      KeptFile.new(name: "vulkan_failed.txt", aside: Aside.new(kind: :diagnostics, reason: "A note that lets the game recover after its graphics fail to start."), holds: "that the game's graphics failed to start on this device, and when"),
      KeptFile.new(name: "fake_store.txt", aside: Aside.new(kind: :test_only, reason: "Used only in test builds, never with a real purchase."), holds: "a pretend purchase, in test builds only"),
      KeptFile.new(name: "shot-<number>.png", aside: Aside.new(kind: :developer_only, reason: "Made only under a developer setting that players never use."), pattern: /\Ashot-\d+\.png\z/,
                   made_by: "the game, only under the developer setting DOT_POPPER_SHOTS", holds: "a screenshot")
    ].freeze

    module SaveFiles
      # Raises unless +file+ is declared in SAVE_FILES.
      def self.declare!(file)
        return if SAVE_FILES.any? { it.covers?(file) }

        raise ArgumentError, "#{file} is not declared in DotPopper::Privacy::SAVE_FILES"
      end
    end
  end
end
