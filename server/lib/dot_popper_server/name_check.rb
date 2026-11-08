# frozen_string_literal: true

module DotPopperServer
  # Whether a display name may be shown to a group, for Apple's guideline
  # 1.2 (doc/decisions.md). Names are the only words players can write, so
  # this is the whole of the filter: short, in letters the game's fonts
  # can draw, no links or addresses, and nothing on the blocklist, also
  # when spelled with look-alike digits or separators.
  module NameCheck
    LONGEST = 16
    ALLOWED = /\A[\p{Latin}\p{Digit} ._'-]+\z/
    LINK = %r{://|www\.|\.(com|net|org|io|gg)\b}i
    LOOK_ALIKES = { "0" => "o", "1" => "i", "3" => "e", "4" => "a", "5" => "s", "7" => "t", "@" => "a", "$" => "s" }.freeze
    BLOCKLIST_FILE = File.expand_path("../../data/blocked_names.txt", __dir__)

    module_function

    # +text+ tidied into a name, or nil when it may not be one.
    def clean(text)
      name = text.to_s.unicode_normalize(:nfc).strip.squeeze(" ")
      name unless name.empty? || name.length > LONGEST || !name.match?(ALLOWED) || name.match?(LINK) || offensive?(name)
    rescue ArgumentError, Encoding::CompatibilityError
      nil
    end

    def offensive?(name)
      squashed = name.downcase.gsub(/[0134 57@$]/) { LOOK_ALIKES.fetch(it, it) }.gsub(/[^\p{Latin}]/, "")
      blocked.any? { squashed.include?(it) }
    end

    def blocked = (@blocked ||= File.readlines(BLOCKLIST_FILE, chomp: true).reject { it.empty? || it.start_with?("#") }.freeze)
  end
end
