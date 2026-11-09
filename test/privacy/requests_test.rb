# frozen_string_literal: true

require "test_helper"
require "socket"
require "json"
require "prism"
require "uri"

# Plays every request the game can make, through a real Session and a real
# Link, against a local server, and reads what actually arrived.
class PrivacyRequestsTest < Minitest::Test
  Groups = DotPopper::Groups
  ROOT = File.expand_path("../..", __dir__)

  GROUP = { "id" => 1, "join_code" => "2345678", "you" => 1, "champion_number" => 1, "top_score" => 0,
            "reign_started_at" => "2026-11-01T00:00:00Z", "members" => [{ "number" => 1, "top_score" => 0 }] }.freeze

  # Runs a job as soon as it starts, on this thread.
  class Instant
    def initialize(link) = (@link = link) && (@done = [])
    def start(job, token) = @done << [job, @link.call(job.verb, job.path, job.body, token)]

    def finished = @done.shift(@done.size)
  end

  def setup
    @heard = []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
    store = DotPopper::ScoreRecord::Memory.new
    @session = Groups::Session.new(store:, worker: Instant.new(Groups::Link.new("http://127.0.0.1:#{@server.addr[1]}")))
  end

  def teardown
    @thread.kill
    @server.close
  end

  def serve
    loop do
      client = @server.accept
      head = +""
      head << client.gets until head.end_with?("\r\n\r\n")
      body = client.read(head[/content-length: (\d+)/i, 1].to_i)
      @heard << [head, body]
      reply = answer(head)
      client.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{reply.bytesize}\r\nConnection: close\r\n\r\n#{reply}")
      client.close
    end
  end

  def answer(head)
    case head[%r{\A\S+ (\S+)}, 1].sub(/\?.*/, "")
    when "/player" then JSON.generate("token" => "tok")
    when "/groups", "/memberships"
      head.start_with?("GET") ? JSON.generate([GROUP]) : JSON.generate(GROUP)
    when %r{\A/groups/\d+\z} then JSON.generate(GROUP)
    when %r{/title_changes\z} then "[]"
    when "/games" then JSON.generate("groups" => [])
    else "{}"
    end
  end

  # Lets the whole conversation finish.
  def pump = 6.times { @session.update(quiet: true) }

  def test_every_request_sent_matches_its_declaration
    @session.join("2345678")
    pump
    @session.refresh
    pump
    @session.create
    pump
    @session.look_at(1)
    pump
    @session.game_finished(score: 7, sized_to_screen: true)
    pump
    @session.leave(1)
    pump
    @session.delete_everything
    pump

    sent = @heard.map { |head, body| [head, body] }
    built = Groups::REQUESTS.reject { |kind, _| Groups::UNBUILT_REQUESTS.include?(kind) }.values

    built.each do |request|
      found = sent.select { |head, _| head.start_with?("#{request.verb.upcase} ") && path_of(head).match?(pattern(request)) }

      refute_empty found, "#{request.kind} was declared but never sent"
      found.each { |head, body| assert_matches(request, head, body) }
    end
    undeclared = sent.reject { |head, _| built.any? { head.start_with?("#{it.verb.upcase} ") && path_of(head).match?(pattern(it)) } }

    assert_empty undeclared.map(&:first), "sent, but declared nowhere"
  end

  def test_a_job_can_only_be_made_from_a_declaration
    assert_raises(KeyError) { Groups::Session::Job.of(:brand_new) }
    assert_raises(ArgumentError) { Groups::Session::Job.of(:join, body: { other: 1 }) }
    assert_raises(NoMethodError) { Groups::Session::Job.new(kind: :join, verb: :get, path: "/x") }
  end

  def test_unbuilt_requests_are_only_those_not_yet_in_the_code
    Groups::UNBUILT_REQUESTS.each do |kind|
      request = Groups::REQUESTS.fetch(kind)
      fields = request.query.keys.join("|")

      refute game_source.match?(/#{fields}/), "#{kind} has been built: remove it from UNBUILT_REQUESTS and play it in this test"
    end
  end

  def test_only_the_link_touches_the_network
    banned = %r{\bNet::|\bTCPSocket\b|\bUDPSocket\b|\bUNIXSocket\b|\bSocket\.|\bOpenSSL\b|\bURI\.open\b|\bopen-uri\b|require\s+["'](?:net/|socket|openssl|open-uri)|HTTParty|Faraday|RestClient|Excon|Typhoeus}

    assert_empty ruby_files.reject { it.end_with?("groups/link.rb") }.select { uncommented(it).match?(banned) }
    assert_empty native_files.select { File.read(it).match?(/URLSession|NSURLConnection|HttpURLConnection|OkHttp|Volley/) }
  end

  private

  def path_of(head) = head[%r{\A\S+ (\S+)}, 1]

  def pattern(request) = %r{\A#{request.path.gsub(":id", "\\d+")}(?:\?|\z)}

  def assert_matches(request, head, body)
    assert_equal request.token, head.match?(/authorization: Bearer /i), "#{request.kind}: token"
    assert_equal request.body.keys.map(&:to_s).sort, (body.to_s.empty? ? {} : JSON.parse(body)).keys.sort, "#{request.kind}: body"
    assert_equal request.query.keys.map(&:to_s).sort, URI.decode_www_form(path_of(head)[/\?(.*)/, 1].to_s).map(&:first).sort, "#{request.kind}: query"
  end

  def ruby_files = Dir[File.join(ROOT, "{lib/**/*.rb,main.rb,bin/*}")].select { File.file?(it) }
  def native_files = Dir[File.join(ROOT, "android/host/src/**/*.java"), File.join(ROOT, "ios/host/Host/*.{swift,m}")]
  def game_source = ruby_files.reject { it.end_with?("groups/requests.rb") }.map { uncommented(it) }.join("\n")

  def uncommented(path)
    source = File.read(path)
    Prism.parse_comments(source).reverse_each { |comment| source[comment.location.start_offset...comment.location.end_offset] = "" }
    source
  end
end
