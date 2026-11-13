# frozen_string_literal: true

require "test_helper"
require "socket"
require "json"
require "prism"
require "uri"
require "dot_popper/privacy/requests"

# Plays every request the game can make, through a real Session and a real
# Link, against a local server, and reads what actually arrived.
class PrivacyRequestsTest < Minitest::Test
  Groups = DotPopper::Groups
  Network = DotPopper::Network
  Privacy = DotPopper::Privacy
  ROOT = File.expand_path("../..", __dir__)

  GROUP = { "id" => 1, "join_code" => "2345678", "you" => 1, "champion_number" => 1, "top_score" => 0,
            "reign_started_at" => "2026-11-01T00:00:00Z", "members" => [{ "number" => 1, "top_score" => 0 }] }.freeze

  # Runs a job as soon as it starts, on this thread.
  class InlineWorker
    def initialize(link) = (@link = link) && (@done = [])
    def start(job, token) = @done << [job, @link.call(job, token)]

    def finished = @done.shift(@done.size)
  end

  # The old name, until no commit uses it.
  Instant = InlineWorker

  def setup
    @heard = []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
    store = DotPopper::ScoreRecord::Memory.new
    @session = Groups::Session.new(store:, worker: InlineWorker.new(Network::Link.new("http://127.0.0.1:#{@server.addr[1]}")))
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
    when %r{/history\z}, "/themes" then "[]"
    when "/games", "/achievements" then JSON.generate("groups" => [])
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
    @session.report_achievements(["steady"])
    pump
    @session.game_finished(score: 7, counts: true)
    pump
    @session.leave(1)
    pump
    DotPopper::ThemeReleases.new(worker: InlineWorker.new(Network::Link.new("http://127.0.0.1:#{@server.addr[1]}")),
                                 themes: DotPopper::Themes.new(DotPopper::ScoreRecord::Memory.new), store: DotPopper::ScoreRecord::Memory.new,
                                 clock: -> { Time.utc(2026, 11, 8, 12) }).ask
    @session.delete_everything
    pump
    play_continuity

    sent = @heard.map { |head, body| [head, body] }
    built = Privacy::REQUESTS.reject { |kind, _| Privacy::UNBUILT_REQUESTS.key?(kind) }.values

    built.each do |request|
      found = sent.select { |head, _| head.start_with?("#{request.verb.upcase} ") && path_of(head).match?(pattern(request)) }

      refute_empty found, "#{request.kind} was declared but never sent"
      found.each { |head, body| assert_matches(request, head, body) }
    end
    undeclared = sent.reject { |head, _| built.any? { head.start_with?("#{it.verb.upcase} ") && path_of(head).match?(pattern(it)) } }

    assert_empty undeclared.map(&:first), "sent, but declared nowhere"
  end

  # group.txt's +sent+: its token and unsent score really go out.
  def test_the_saved_token_and_unsent_score_leave_the_device
    store = DotPopper::ScoreRecord::Memory.new("tok\n7\n1\n")
    @session = Groups::Session.new(store:, worker: InlineWorker.new(Network::Link.new("http://127.0.0.1:#{@server.addr[1]}")))
    @session.refresh
    pump

    game = @heard.find { |head, _| head.start_with?("POST /games") }

    assert_match(/authorization: Bearer tok/i, game.first)
    assert_equal({ "score" => 7 }, JSON.parse(game.last))
  end

  def test_a_job_can_only_be_made_from_a_declaration
    themes = DotPopper::ThemeReleases::REQUESTS.fetch(:themes)

    assert_raises(KeyError) { Groups::Job.new(:brand_new) }
    assert_raises(ArgumentError) { Groups::Job.new(:join, body: { other: 1 }) }
    assert_raises(ArgumentError) { Groups::Job.new(:join, verb: :get, path: "/x") }
    assert_raises(ArgumentError) { Network::Job.of(themes) }
    assert_raises(ArgumentError) { Network::Job.of(themes, query: { started_on: "2026-11-08", other: 1 }) }
    assert_raises(ArgumentError) { Network::Job.of(themes, query: { started_on: "2026-11-08" }, body: { other: 1 }) }
    assert_raises(NoMethodError) { Network::Job.new(kind: :themes, verb: :get, path: "/x", body: nil) }
    assert_raises(NoMethodError) { Network::Job[:themes, :get, "/x", nil] }
  end

  # A request counts as built once a query field it declares appears in
  # the game's code outside privacy/requests.rb. The scan is shown to find
  # every built request that has one, so it is not blind while
  # UNBUILT_REQUESTS is empty, and an unbuilt request must have a query
  # field for it to find.
  def test_unbuilt_requests_are_only_those_not_yet_in_the_code
    source = game_source
    in_code = ->(request) { request.query.keys.any? { source.match?(/\b#{it}\b/) } }
    built = Privacy::REQUESTS.values.reject { Privacy::UNBUILT_REQUESTS.key?(it.kind) }.reject { it.query.empty? }

    refute_empty built
    built.each { assert in_code.call(it), "the scan does not find #{it.kind}'s query fields, though it is built" }
    Privacy::UNBUILT_REQUESTS.each_value do |request|
      refute_empty request.query, "#{request.kind} has no query field, so this test cannot tell when it is built"
      refute in_code.call(request), "#{request.kind} has been built: remove it from UNBUILT_REQUESTS and play it in this test"
    end
  end

  # A request is declared only in a part's REQUESTS, and every part's are
  # in the document.
  def test_every_declaration_is_in_privacy_requests
    parts = Privacy::PARTS.map { it.const_source_location(:REQUESTS).first }
    game = ruby_files.reject { it.include?("dot_popper/privacy/") }

    assert_equal parts.tally, game.to_h { [it, uncommented(it).scan(/\bREQUESTS\s*=/).size] }.reject { _2.zero? }
    assert_empty game.reject { parts.include?(it) }.select { uncommented(it).match?(/\bRequest\.new\b/) }
  end

  def test_only_the_link_touches_the_network
    banned = %r{\bNet::|\bTCPSocket\b|\bUDPSocket\b|\bUNIXSocket\b|\bSocket\.|\bOpenSSL\b|\bURI\.open\b|\bopen-uri\b|require\s+["'](?:net/|socket|openssl|open-uri)|HTTParty|Faraday|RestClient|Excon|Typhoeus}

    # automation.rb only refuses connections (Automation.guard!); it opens none.
    # continuity/ed25519.rb takes OpenSSL's signatures, and nothing that connects.
    signatures = File.join(ROOT, "lib/dot_popper/continuity/ed25519.rb")
    # receipt.rb and receipt/ check stores' signatures and certificates,
    # and nothing that connects.
    receipts = ruby_files.select { it.end_with?("dot_popper/receipt.rb") || it.include?("dot_popper/receipt/") }

    assert_empty ruby_files.reject { it.end_with?("network/link.rb", "dot_popper/automation.rb") || it == signatures || receipts.include?(it) }.select { uncommented(it).match?(banned) }
    assert_empty uncommented(signatures).gsub(/OpenSSL::PKey\b|require "openssl"/, "").scan(banned)
    receipts.each { assert_empty uncommented(it).gsub(/OpenSSL::(?:PKey|X509|ASN1|BN)\b|require "openssl"/, "").scan(banned), it }
    assert_empty native_files.select { File.read(it).match?(/URLSession|NSURLConnection|HttpURLConnection|OkHttp|Volley/) }
  end

  private

  # The proof, a key's entry and check, and the three connectivity checks,
  # each pointed at this machine with its own path; none answers as
  # expected, so every connectivity check is asked.
  def play_continuity
    c = DotPopper::Continuity
    local = "http://127.0.0.1:#{@server.addr[1]}"
    server = c::SetdefServer.new(Network::Link.new(local))
    license = c::License.new(DotPopper::ScoreRecord::Memory.new, pins: c::TEST_PINS)
    license.enter(c::LicenseKey.issue(c::TestKeys::LICENSE).text)
    server.proof(c::SignedAnswers.fresh)
    server.ask(license.due(c::SignedAnswers.fresh))
    license.instance_variable_get(:@lines)["registered"] = "yes"
    server.ask(license.due(c::SignedAnswers.fresh))

    refute c::Connectivity.new(link: ->(_host) { Network::Link.new(local, raw: true) }).online?
  end

  def path_of(head) = head[%r{\A\S+ (\S+)}, 1]

  def pattern(request) = %r{\A#{request.path.gsub(":id", "\\d+")}(?:\?|\z)}

  def assert_matches(request, head, body)
    assert_equal request.token, head.match?(/authorization: Bearer /i), "#{request.kind}: token"
    assert_equal request.body.keys.map(&:to_s).sort, (body.to_s.empty? ? {} : JSON.parse(body)).keys.sort, "#{request.kind}: body"
    assert_equal request.query.keys.map(&:to_s).sort, URI.decode_www_form(path_of(head)[/\?(.*)/, 1].to_s).map(&:first).sort, "#{request.kind}: query"
  end

  def ruby_files = Dir[File.join(ROOT, "{lib/**/*.rb,main.rb,bin/*}")].select { File.file?(it) }
  def native_files = Dir[File.join(ROOT, "android/host/src/**/*.java"), File.join(ROOT, "ios/host/Host/*.{swift,m}")]
  def game_source = ruby_files.reject { it.end_with?("privacy/requests.rb") }.map { uncommented(it) }.join("\n")

  def uncommented(path)
    source = File.read(path)
    Prism.parse_comments(source).reverse_each { |comment| source[comment.location.start_offset...comment.location.end_offset] = "" }
    source
  end
end
