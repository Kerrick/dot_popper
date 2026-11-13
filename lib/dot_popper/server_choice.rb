# frozen_string_literal: true

module DotPopper
  # The server friend groups and themes use, which a player may change
  # only while setdef is gone (+gone+, Continuity::Gone), to one someone
  # else runs from the game's published API. The address comes from the
  # clipboard, so nothing is typed, and must be HTTPS. It is kept in the
  # +store+ (server.txt) and used from the next start, since a group
  # belongs to one server. A server only ever holds groups and themes: it
  # never grants Pro. When setdef's server answers again, Change Server
  # goes away and the game goes back to setdef's (#forget).
  class ServerChoice
    def initialize(store, gone:, clipboard:)
      @store = store
      @gone = gone
      @clipboard = clipboard
      @status = nil
    end

    # What the last paste came to: :chosen, :not_https or :empty; nil
    # until one.
    attr_reader :status

    # Whether Settings offers Change Server.
    def offered? = @gone.gone?

    # The replacement's address, or nil for setdef's own.
    def address
      text = @store.read.to_s.strip
      text.empty? ? nil : text
    end

    # The address the game connects to: a replacement's only while setdef
    # is gone, and +own+ otherwise.
    def server_url(own)
      chosen = address
      offered? && chosen ? chosen : own
    end

    # Takes the address on the clipboard.
    def paste
      text = @clipboard.paste.to_s.strip
      return @status = :empty if text.empty?
      return @status = :not_https unless self.class.https?(text)

      @store.write("#{text}\n")
      @status = :chosen
    end

    # Back to setdef's own address.
    def reset
      @store.write("")
      @status = nil
    end

    # Whether setdef answered again and a replacement is still kept.
    def forget
      reset if !offered? && address
    end

    # Hears Continuity::Gone: once setdef answers again, a chosen server
    # is forgotten, and the game returns to setdef's.
    def call(event)
      forget if event.is_a?(Continuity::SetdefHere)
    end

    # Whether +text+ is one HTTPS address with a host, and nothing else.
    def self.https?(text)
      require "uri"
      uri = URI.parse(text)
      uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty? && uri.userinfo.nil? && !text.match?(/\s/)
    rescue URI::Error
      false
    end
  end
end
