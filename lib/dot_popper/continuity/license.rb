# frozen_string_literal: true

module DotPopper
  module Continuity
    # This device's license key, if a player entered one, and its place in
    # "one key, one device at a time". The key gives Pro the moment it
    # verifies, offline (LicenseKey#valid?), and nothing but a signed
    # "moved" from setdef's server takes it away: no answer, a refusal, an
    # unsigned or wrongly signed answer, or no internet never does.
    #
    # The server keeps only the SHA-256 of a secret this device chose. Entering
    # a key sends a fresh +secret+ (POST /licenses), which moves the key here.
    # Each check after (POST /license_checks) sends the secret and a fresh
    # +next+, both kept until a signed answer comes, so a retry is always
    # the same request; "current" keeps only +next+, as the new secret.
    #
    # The store (read, write(text), as ScoreRecord's) keeps four lines:
    # "key: DP-…", "secret: <hex>", "next: <hex>" while a check waits,
    # and "registered: yes" once the server has answered the entry.
    class License
      # What setdef's server is to be asked: +kind+ (:license_entry or
      # :license_check, as Groups::REQUESTS names them) and the +body+ to send.
      Due = Data.define(:kind, :body)

      def initialize(store, pins: PINNED, fresh: -> { SignedAnswers.fresh })
        @store = store
        @pins = pins
        @fresh = fresh
        @lines = read
      end

      # The verified key, or nil. It is checked once for each key kept,
      # since Pro is asked about many times a frame.
      def key
        text = @lines["key"]
        return @key if @checked == text

        @checked = text
        parsed = LicenseKey.parse(text)
        @key = (parsed if parsed&.valid?(@pins))
      end

      def pro? = !key.nil?

      # Takes +text+ as a license key: :entered, :same for the key already
      # here, or :invalid. A new key is Pro at once, and owes the server an
      # entry.
      def enter(text)
        entered = LicenseKey.parse(text)
        return :invalid unless entered&.valid?(@pins)
        return :same if entered == key

        @lines = { "key" => entered.text, "secret" => Continuity.hex(@fresh.call) }
        save
        :entered
      end

      # What setdef's server should be asked next, with a fresh nonce, or
      # nil with no key. A check's +next+ is saved before it is sent.
      def due(nonce)
        current = key or return nil
        hex = Continuity.hex(nonce)
        return Due.new(kind: :license_entry, body: { key: current.text, secret: @lines["secret"], nonce: hex }) unless registered?

        unless @lines["next"]
          @lines["next"] = Continuity.hex(@fresh.call)
          save
        end
        Due.new(kind: :license_check, body: { key_id: Continuity.hex(current.id), secret: @lines["secret"], next: @lines["next"], nonce: hex })
      end

      # The server's +reply+ (Groups::Reply) to +due+, asked with +nonce+.
      # Answers the verdict it acted on, or nil when it was no answer.
      def heard(due, nonce, reply)
        current = key or return nil
        return nil unless reply.ok? && due.body[:secret] == @lines["secret"]

        verdict = SignedAnswers.verdict(reply.body, current.id, nonce, @pins)
        case verdict
        when :current then accepted(due)
        when :moved then moved
        end
        verdict
      end

      def registered? = @lines["registered"] == "yes"

      private

      def accepted(due)
        if due.kind == :license_entry
          @lines["registered"] = "yes"
        else
          @lines["secret"] = due.body[:next]
          @lines.delete("next")
        end
        save
      end

      # The key went to another device: this one is Free again.
      def moved
        @lines = {}
        save
      end

      def read = @store.read.to_s.lines.filter_map { it.split(":", 2).map(&:strip) if it.include?(":") }.to_h

      def save = @store.write(@lines.map { |name, value| "#{name}: #{value}\n" }.join)
    end
  end
end
