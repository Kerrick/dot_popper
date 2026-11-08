# frozen_string_literal: true

module DotPopper
  module Shell
    # The file the host writes the store's answers to, for
    # Presentation::Storefront. It is a plain file in the save folder,
    # named to the host in full, and not a SaveFile: it is read a few times
    # a second and is usually absent, which is nothing to warn about.
    class StoreAnswers < Data.define(:path)
      NAME = "store_answer.txt"

      def self.in_save_folder = new(path: File.join(::Lota::Filesystem.save_directory, NAME))

      def read
        File.read(path)
      rescue SystemCallError
        nil
      end

      def remove
        File.delete(path)
      rescue SystemCallError
        nil
      end
    end
  end
end
