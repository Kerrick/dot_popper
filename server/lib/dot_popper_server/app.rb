# frozen_string_literal: true

require "json"
require "rack"

module DotPopperServer
  # The HTTP face of the Store, as a Rack app. A player is known by the
  # bearer token only. It is friends-only trust: the server decides the
  # trophy, but takes a client's word for a round's score and for a
  # creator having paid (doc/decisions.md). Nothing a player writes is read:
  # a member is a mark from DotPopper::Groups::Mark, or the request is refused.
  class App
    LONGEST_BODY = 4096
    HIGHEST_SCORE = 100_000

    ROUTES = {
      ["POST", "/v1/players"] => :create_player,
      ["DELETE", "/v1/players/me"] => :delete_me,
      ["POST", "/v1/groups"] => :create_group,
      ["POST", "/v1/groups/join"] => :join_group,
      ["DELETE", "/v1/groups/mine"] => :leave_group,
      ["GET", "/v1/group"] => :group,
      ["POST", "/v1/rounds"] => :round,
      ["POST", "/v1/news/seen"] => :news_seen
    }.freeze

    def initialize(store) = @store = store

    def call(env)
      request = Rack::Request.new(env)
      return [200, { "content-type" => "text/plain" }, ["ok"]] if request.path == "/health"

      respond(*dispatch(request, body_of(request)))
    rescue Store::Refused => e
      respond(e.status, { error: e.message })
    rescue JSON::ParserError, TypeError
      respond(400, { error: "bad_request" })
    rescue TooLarge
      respond(413, { error: "too_large" })
    end

    private

    class TooLarge < StandardError; end

    def dispatch(request, body)
      action = ROUTES[[request.request_method, request.path]]
      return public_send_action(action, request, body) if action


      [404, { error: "not_found" }]
    end

    def public_send_action(action, request, body)
      return create_player if action == :create_player

      player = @store.player(bearer(request)) or return [401, { error: "unknown_token" }]
      send(action, player, body)
    end

    def bearer(request) = request.get_header("HTTP_AUTHORIZATION").to_s[/\ABearer (.+)\z/, 1]

    def body_of(request)
      text = request.body&.read(LONGEST_BODY + 1).to_s
      raise TooLarge if text.bytesize > LONGEST_BODY

      text.empty? ? {} : JSON.parse(text)
    end

    def respond(status, payload = nil)
      return [status, {}, []] if payload.nil?

      [status, { "content-type" => "application/json" }, [JSON.generate(payload)]]
    end

    def create_player = [201, @store.create_player]

    def delete_me(player, _body)
      @store.delete_player(player["id"])
      [204]
    end

    def create_group(player, body) = [201, { group: @store.create_group(player["id"], body["mark"]) }]
    def join_group(player, body) = [200, { group: @store.join_group(player["id"], body["code"], body["mark"]) }]

    def leave_group(player, _body)
      @store.leave_group(player["id"])
      [204]
    end

    def group(player, _body) = [200, { group: @store.view(player["id"]) }]

    def round(player, body)
      score = Integer(body["score"], exception: false)
      return [422, { error: "bad_score" }] unless score&.between?(0, HIGHEST_SCORE)
      return [422, { error: "round_does_not_count" }] unless DotPopper::Trophy.counts?(sized_to_screen: body["sized_to_screen"])

      [200, @store.report_round(player["id"], score)]
    end

    def news_seen(player, body)
      @store.mark_seen(player["id"], Array(body["ids"]).grep(Integer))
      [200, { ok: true }]
    end
  end
end
