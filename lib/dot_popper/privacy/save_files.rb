# frozen_string_literal: true

require_relative "../../dot_popper"

module DotPopper
  module Privacy
    # A file the game keeps in its save folder. +name+ is the name, or how
    # a dated name looks; +pattern+ matches a dated name (nil for a fixed
    # one). Everything here stays on the device.
    class KeptFile < Data.define(:name, :pattern, :holds, :made_by)
      def initialize(name:, holds:, pattern: nil, made_by: "the game") = super

      def covers?(file) = pattern ? pattern.match?(file) : name == file
    end

    # Every file in the save folder, by Shell::SaveFile's refusal and
    # test/privacy/save_files_test.rb.
    SAVE_FILES = [
      KeptFile.new(name: "score_record.txt", holds: "your best score for each dot size"),
      KeptFile.new(name: "stats.txt", holds: "your statistics: totals, chart bars and goal streak"),
      KeptFile.new(name: "achievements.txt", holds: "your achievements and the day each was earned"),
      KeptFile.new(name: "entitlement.txt", holds: "whether Pro was bought"),
      KeptFile.new(name: "themes.txt", holds: "your themes and which is chosen"),
      KeptFile.new(name: "games.txt", holds: "how many free games are left and used today"),
      KeptFile.new(name: "games.csv", holds: "a history of your games: when, score, and how each went"),
      KeptFile.new(name: "dot_size.txt", holds: "your choice of dot size"),
      KeptFile.new(name: "sound.txt", holds: "your sound setting"),
      KeptFile.new(name: "taught.txt", holds: "what the game has already shown you"),
      KeptFile.new(name: "tutorial.txt", holds: "whether you have played the tutorial"),
      KeptFile.new(name: "group.txt", holds: "your anonymous group token, an unsent score, whether you were in a group, and the newest title change you were shown of each"),
      KeptFile.new(name: "cleared.txt", holds: "the names of the backups made by the last clearing of your records"),
      KeptFile.new(name: "vulkan_failed.txt", holds: "that the Vulkan renderer failed on this device, and when"),
      KeptFile.new(name: "fake_store.txt", holds: "a pretend purchase, in test builds only"),
      KeptFile.new(name: "store_answer.txt", made_by: "the iOS or Android host, read by the game", holds: "what the store last answered about Pro"),
      KeptFile.new(name: "<record>-YYYYMMDD-HHMMSS.txt", pattern: StatsKeeper::BACKUP, holds: "a backup of your records from when you cleared them"),
      KeptFile.new(name: "games-YYYYMMDD-HHMMSS.csv", pattern: /\Agames-\d{8}-\d{6}\.csv\z/, holds: "an older game history, kept whole when its columns changed"),
      KeptFile.new(name: "shot-<number>.png", pattern: /\Ashot-\d+\.png\z/, made_by: "the game, only under the developer setting DOT_POPPER_SHOTS",
                   holds: "a screenshot")
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
