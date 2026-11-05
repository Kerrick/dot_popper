# frozen_string_literal: true

module DotPopper
  module Shell
    # A small text file in the game's save folder, as a store for
    # BestScore and for settings: it answers read and write(text). A save
    # folder that cannot be read or written loses the value, never the
    # game.
    class SaveFile
      def initialize(name)
        @name = name
      end

      def read
        contents, = ::Lota::Filesystem.read(@name)
        contents
      rescue StandardError => e
        warn "Dot Popper: could not read #{@name}: #{e.message}"
        nil
      end

      def write(text)
        saved, message = ::Lota::Filesystem.write(@name, text)
        warn "Dot Popper: could not save #{@name}: #{message}" unless saved
        text
      rescue StandardError => e
        warn "Dot Popper: could not save #{@name}: #{e.message}"
        text
      end
    end
  end
end
