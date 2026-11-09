# frozen_string_literal: true

# A stand-in for the friend groups' server, in memory, for trying the
# game's screens without one: `ruby script/group_stub.rb [port]`, then run
# the game with DOT_POPPER_SERVER=http://127.0.0.1:9293. It answers the
# game's whole API, and starts with groups to look at: one full of members
# with a history of its title, joined by code 1234567.

require "json"
require "socket"

# The server's rules and its answers, without the sockets.
class GroupStub
  Reply = Data.define(:status, :body)
  SCORES = [412, 388, 301, 276, 240, 199, 150, 92].freeze

  def initialize
    @tokens = 0
    @groups = {}
    @changes = {}
    @next_id = 1
    @next_change = 1
    seed
  end

  def call(verb, path, body, token)
    route = "#{verb} #{path}"
    return Reply.new(201, { token: "stub#{@tokens += 1}" }) if route == "POST /player"
    return Reply.new(401, {}) unless token

    respond(route, body)
  end

  private

  def respond(route, body)
    case route
    when "DELETE /player" then Reply.new(204, nil)
    when "GET /groups" then Reply.new(200, @groups.values.select { it[:joined] }.map { group_json(it) })
    when "POST /groups" then Reply.new(201, group_json(new_group(you: 1, joined: true)))
    when "POST /memberships" then join(body["join_code"])
    when "POST /games" then cabinet(body["score"].to_i)
    when %r{\AGET /groups/(\d+)\z} then one($1.to_i)
    when %r{\AGET /groups/(\d+)/title_changes\z} then Reply.new(200, @changes.fetch($1.to_i, []).first(20))
    when %r{\ADELETE /groups/(\d+)/membership\z} then leave($1.to_i)
    else Reply.new(404, {})
    end
  end

  def join(code)
    group = @groups.values.find { it[:join_code] == code }
    return Reply.new(404, {}) unless group
    return Reply.new(409, { error: "already_member" }) if group[:joined]

    group[:joined] = true
    Reply.new(201, group_json(group))
  end

  def one(id) = @groups[id]&.fetch(:joined) ? Reply.new(200, group_json(@groups[id])) : Reply.new(404, {})

  def leave(id)
    @groups[id][:joined] = false if @groups[id]
    Reply.new(204, nil)
  end

  def cabinet(score)
    Reply.new(200, { groups: @groups.values.select { it[:joined] }.map { { group: group_json(play(it, score)), won_title: it[:won] } } })
  end

  def play(group, score)
    group[:won] = score > group[:top_score] && group[:champion] != group[:you]
    group[:members][group[:you]] = [group[:members][group[:you]], score].max
    group.merge!(top_score: score) if score > group[:top_score] && !group[:won]
    return group unless group[:won]

    previous = group[:champion]
    change = { id: @next_change, champion_number: group[:you], previous_champion_number: previous, score:, won_at: Time.now.utc.iso8601 }
    @next_change += 1
    @changes[group[:id]] = [change, *@changes[group[:id]]]
    group[:members][group[:you]] = score
    group.merge!(top_score: score, champion: group[:you], reign_started_at: change[:won_at])
  end

  def new_group(you:, joined:)
    id = @next_id
    @next_id += 1
    @changes[id] = []
    @groups[id] = { id:, join_code: "99#{format('%05d', id)}", you:, joined:, members: { you => 0 }, champion: nil, top_score: 0, reign_started_at: nil }
  end

  def group_json(group)
    { id: group[:id], join_code: group[:join_code], you: group[:you],
      members: group[:members].map { |number, top_score| { number:, top_score: } },
      champion_number: group[:champion], top_score: group[:top_score], reign_started_at: group[:reign_started_at] }
  end

  def seed
    main = new_group(you: 3, joined: false).merge!(join_code: "1234567", champion: 7, top_score: SCORES.first, reign_started_at: "2026-11-05T12:00:00Z")
    main[:members] = (1..8).to_h { |number| [number, number == 7 ? SCORES.first : SCORES[number % SCORES.size]] }
    @changes[main[:id]] = seed_changes
    rival = new_group(you: 2, joined: true)
    rival.merge!(members: { 1 => 120, 2 => 240, 3 => 60 }, champion: 2, top_score: 240, reign_started_at: "2026-11-01T09:00:00Z")
    new_group(you: 1, joined: true)
  end

  def seed_changes
    Array.new(11) do |i|
      champion = i.zero? ? 7 : ((i * 3) % 8) + 1
      previous = i == 10 ? nil : ((i + 1) * 3 % 8) + 1
      { id: 100 - i, champion_number: champion, previous_champion_number: previous, score: SCORES.first - (i * 17), won_at: format("2026-10-%02dT10:00:00Z", 28 - i) }
    end
  end
end

def serve(port)
  stub = GroupStub.new
  server = TCPServer.new("127.0.0.1", port)
  loop do
    client = server.accept
    Thread.new(client) { handle(stub, it) }
  end
end

def handle(stub, client)
  verb, target = client.gets.split
  headers = {}
  while (line = client.gets) && line != "\r\n"
    name, value = line.split(":", 2)
    headers[name.downcase] = value.strip
  end
  text = headers["content-length"] ? client.read(headers["content-length"].to_i) : ""
  body = text.empty? ? {} : JSON.parse(text)
  reply = stub.call(verb, target, body, headers["authorization"])
  payload = reply.body.nil? ? "" : JSON.generate(reply.body)
  client.write("HTTP/1.1 #{reply.status} X\r\nContent-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}")
ensure
  client.close
end

if __FILE__ == $PROGRAM_NAME
  require "time"
  serve(Integer(ARGV.fetch(0, "9293")))
end
