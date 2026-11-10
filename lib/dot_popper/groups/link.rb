# frozen_string_literal: true

module DotPopper
  module Groups
    # A server's answer: its status and parsed body, or status 0 when it
    # could not be reached at all. +retry_after+ is the seconds a 429
    # asks the player to wait, or nil.
    class Reply < Data.define(:status, :body, :retry_after)
      def initialize(status:, body:, retry_after: nil) = super

      def self.offline = new(status: 0, body: {})

      def ok? = status.between?(200, 299)
      def offline? = status.zero?
    end

    # One HTTPS request at a time, by Net::HTTP. net/http, openssl and
    # json are required here, on the worker's thread, on first use, so
    # the game starts as fast as ever and a player who never joins a
    # group never loads them. Whatever goes wrong, the answer is
    # Reply.offline: no network, no certificates, a missing library.
    class Link
      OPEN_SECONDS = 5
      READ_SECONDS = 8
      VERBS = { get: "Get", post: "Post", put: "Put", delete: "Delete" }.freeze

      # +raw+ keeps a body as the text it is, for an answer that is not
      # JSON, as a connectivity check's (Continuity::Connectivity).
      def initialize(url, raw: false)
        @url = url
        @raw = raw
      end

      def call(verb, path, body, token)
        require "net/http"
        require "json"
        uri = URI.join(@url, path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = OPEN_SECONDS
        http.read_timeout = READ_SECONDS
        parse(http.start { it.request(request(verb, uri, body, token)) })
      rescue StandardError, ScriptError => e
        warn "Dot Popper: could not reach the group server: #{e.class}"
        Reply.offline
      end

      private

      def request(verb, uri, body, token)
        request = Net::HTTP.const_get(VERBS.fetch(verb)).new(uri)
        request["Authorization"] = "Bearer #{token}" if token
        if body
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(body)
        end
        request
      end

      def parse(response)
        text = response.body.to_s
        status = response.code.to_i
        wait = Integer(response["Retry-After"].to_s, 10, exception: false)
        return Reply.new(status:, body: text, retry_after: wait) if @raw

        Reply.new(status:, body: text.empty? ? {} : JSON.parse(text), retry_after: wait)
      rescue JSON::ParserError
        # A refusal with a page for a body is still a refusal.
        status.between?(200, 299) ? Reply.offline : Reply.new(status:, body: {}, retry_after: wait)
      end
    end
  end
end
