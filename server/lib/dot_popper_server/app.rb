# frozen_string_literal: true

require "json"
require "rack"

module DotPopperServer
  # The HTTP face of the Store, as a Rack app. A player is known by the
  # bearer token only. It is friends-only trust: the server decides the
  # trophy, but takes a client's word for a round's score and for a
  # creator having paid (doc/decisions.md).
  class App
    LONGEST_BODY = 4096
    HIGHEST_SCORE = 100_000

    ROUTES = {
      ["POST", "/v1/players"] => :create_player,
      ["PUT", "/v1/players/me"] => :rename,
      ["DELETE", "/v1/players/me"] => :delete_me,
      ["POST", "/v1/groups"] => :create_group,
      ["POST", "/v1/groups/join"] => :join_group,
      ["DELETE", "/v1/groups/mine"] => :leave_group,
      ["GET", "/v1/group"] => :group,
      ["POST", "/v1/rounds"] => :round,
      ["POST", "/v1/news/seen"] => :news_seen
    }.freeze

    MEMBER_ROUTE = %r{\A/v1/members/(\d+)/(block|report)\z}

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

      member = MEMBER_ROUTE.match(request.path)
      return member_action(request, member[1].to_i, member[2]) if member

      [404, { error: "not_found" }]
    end

    def public_send_action(action, request, body)
      return create_player(body) if action == :create_player

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

    def name_of(body)
      NameCheck.clean(body["name"]) or raise Store::Refused.new("bad_name", 422)
    end

    def create_player(body)
      [201, @store.create_player(name_of(body))]
    end

    def rename(player, body)
      @store.rename(player["id"], name_of(body))
      [200, { ok: true }]
    end

    def delete_me(player, _body)
      @store.delete_player(player["id"])
      [204]
    end

    def create_group(player, _body) = [201, { group: @store.create_group(player["id"]) }]
    def join_group(player, body) = [200, { group: @store.join_group(player["id"], body["code"]) }]

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

    def member_action(request, other_id, action)
      player = @store.player(bearer(request)) or return [401, { error: "unknown_token" }]
      case [request.request_method, action]
      in ["POST", "block"] then @store.block(player["id"], other_id)
      in ["DELETE", "block"] then @store.unblock(player["id"], other_id)
      in ["POST", "report"] then @store.report(player["id"], other_id)
      else return [404, { error: "not_found" }]
      end
      [200, { group: @store.view(player["id"]) }]
    end
  end
end
