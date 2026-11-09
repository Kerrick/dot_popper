# frozen_string_literal: true

require_relative "../privacy/save_files"

module DotPopper
  module Shell
    # A small text file in the game's save folder, as a store for
    # ScoreRecord and for settings: it answers read, write(text), and
    # remove, for RecordKeeper's backups. A save
    # folder that cannot be read or written loses the value, never the
    # game. A name not declared in Privacy::SAVE_FILES is refused: no file
    # exists that the privacy document does not list.
    class SaveFile < Data.define(:name)
      def initialize(name:)
        Privacy::SaveFiles.declare!(name)
        super
      end

      def read
        contents, = ::Lota::Filesystem.read(name)
        contents
      rescue StandardError => e
        warn "Dot Popper: could not read #{name}: #{e.message}"
        nil
      end

      def write(text)
        saved, message = ::Lota::Filesystem.write(name, text)
        warn "Dot Popper: could not save #{name}: #{message}" unless saved
        text
      rescue StandardError => e
        warn "Dot Popper: could not save #{name}: #{e.message}"
        text
      end

      def remove
        ::Lota::Filesystem.remove(name) if ::Lota::Filesystem.info(name)
      rescue StandardError => e
        warn "Dot Popper: could not remove #{name}: #{e.message}"
      end
    end
  end
end
