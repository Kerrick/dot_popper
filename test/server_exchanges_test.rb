# frozen_string_literal: true

require "test_helper"
require "digest"
require "json"
require "socket"
require "dot_popper/presentation"

# Replays the server's own record of every exchange (its
# docs/exchanges.json, made by its tests against its real app, copied to
# test/fixtures/server/) with the game's own client: Groups::Session,
# ThemeReleases, License and SetdefServer, through a real Network::Link, to a
# local socket that answers only what the record holds, and refuses any
# request it doesn't hold exactly. So the game can change nothing it
# sends or reads without this failing, and a new copy of the record
# fails it when the server has changed what it answers.
class ServerExchangesTest < Minitest::Test
  C = DotPopper::Continuity
  Groups = DotPopper::Groups
  Network = DotPopper::Network
  COPY = File.expand_path("fixtures/server/exchanges.json", __dir__)
  RECORD = JSON.parse(File.read(COPY))
  H = ->(hex) { [hex].pack("H*") }

  # Runs a job as soon as it starts, on this thread.
  class InlineWorker
    def initialize(link) = (@link = link) && (@done = [])
    def start(job, token) = @done << [job, @link.call(job, token)]
    def finished = @done.shift(@done.size)
  end

  # The theme keys the feed hands over.
  class Themes
    attr_reader :keys

    def release(keys) = (@keys = keys) && true
  end

  def setup
    @exchanges = RECORD.fetch("exchanges").map(&:dup)
    @strangers = []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
    @url = "http://127.0.0.1:#{@server.addr[1]}"
  end

  def teardown
    @thread.kill
    @server.close
  end

  def test_the_game_makes_every_exchange_and_reads_each_reply_as_the_server_means_it
    play_continuity
    play_friend_groups
    play_themes

    assert_empty @strangers, "the game sent requests the server's record doesn't hold"
    assert_empty @exchanges.reject { it["used"] }.map { it["name"] }, "exchanges the game never made"
  end

  def test_the_values_both_sides_hold_are_the_servers
    values = RECORD.fetch("values")

    assert_equal [C::Certificate::PROOF, C::Certificate::SIGNING_LABEL, C::LicenseKey::LABEL, C::SignedAnswers::LICENSE],
                 values.fetch("labels").values_at("proof", "certificate", "license_key", "license_check").map { C.label(it) }
    assert_equal [C::Certificate::SIZE, C::Certificate::MAGIC, C::Certificate::VERSION], values.fetch("certificate").values_at("size", "magic", "version")
    assert_equal [C::LicenseKey::SIZE, C::LicenseKey::VERSION, C::LicenseKey::PREFIX, C::LicenseKey::ALPHABET, C::LicenseKey::LETTERS],
                 values.fetch("license_key").values_at("size", "version", "prefix", "alphabet", "letters")
    assert_equal C::SignedAnswers::VERDICTS, values.fetch("verdicts")
    assert_equal Groups::Session::HIGHEST_SCORE, values.fetch("highest_score")
    assert_equal DotPopper::Presentation::GroupWords::CODE_LENGTH, values.fetch("join_code_digits")
    assert_equal Groups::Session::LONGEST_RETRY_WAIT, values.fetch("retry_after")
    assert_includes File.read(File.expand_path("../doc/server.md", __dir__)),
                    "A player can be in at most #{values.fetch("max_groups")} groups; a group holds at most #{values.fetch("max_members")} at once."
  end

  def test_every_achievement_and_theme_key_is_one_the_server_takes
    values = RECORD.fetch("values")

    assert_empty DotPopper::Achievement::IDS.map(&:to_s).grep_v(Regexp.new(values.fetch("achievement_key_format")))
    assert_empty DotPopper::Theme::ALL.map { it.key.to_s }.grep_v(Regexp.new(values.fetch("theme_key_format")))
  end

  # The server accepts the privacy document a release publishes only in
  # this shape (the server's PrivacyPolicy::GameDocument).
  def test_the_privacy_document_has_the_shape_the_server_takes
    document = JSON.parse(File.read(File.expand_path("../doc/privacy.json", __dir__)))

    assert_empty shape_problems(RECORD.dig("values", "privacy_document_shape"), document, "the document")
  end

  def test_the_copy_is_the_one_the_server_published
    stated = File.read(File.expand_path("../doc/server.md", __dir__))[/`test\/fixtures\/server\/exchanges\.json`, whose SHA-256 is `(\h{64})`/, 1]

    assert_equal Digest::SHA256.file(COPY).hexdigest, stated
  end

  # With DOT_POPPER_SERVER_CHECKOUT naming a checkout of the server's
  # repository, the copy must be the server's current record.
  def test_the_copy_is_the_servers_current_record
    server = ENV.fetch("DOT_POPPER_SERVER_CHECKOUT", "")
    skip "DOT_POPPER_SERVER_CHECKOUT names no checkout of the server" if server.empty?

    assert_equal File.binread(File.join(server, "docs/exchanges.json")), File.binread(COPY), "copy the server's docs/exchanges.json again"
  end

  private

  def play_continuity
    pins = C::Pins.of(roots: RECORD.dig("keys", "roots"), license_keys: RECORD.dig("keys", "license_keys"))
    server = C::SetdefServer.new(Network::Link.new(@url))

    proving = exchange("setdef's server proves itself")
    nonce = H[proving.dig("request", "path")[/nonce=(\h+)/, 1]]
    assert C::SignedAnswers.proof?(server.proof(nonce).body, nonce, pins)
    assert_equal proving["signed"], C.hex(C::SignedAnswers::PROOF + nonce)

    entering, checking, again, elsewhere, moving = exchange("a device enters a license key"), exchange("the device checks it still holds the key"),
      exchange("the device asks again after losing the answer"), exchange("another device enters the same key"), exchange("the first device learns the key has moved")
    text = entering.dig("request", "body", "key")
    secrets = [entering, checking, moving].map { H[body(it).fetch(it.equal?(entering) ? "secret" : "next")] }
    first = C::License.new(DotPopper::ScoreRecord::Memory.new, pins:, fresh: -> { secrets.shift })
    second = C::License.new(DotPopper::ScoreRecord::Memory.new, pins:, fresh: -> { H[body(elsewhere).fetch("secret")] })

    assert_equal :entered, first.enter(text)
    assert_equal :current, ask(server, first, entering)
    lost = first.due(nonce_of(checking))
    server.ask(lost)
    assert_nil first.heard(lost, nonce_of(checking), Network::Reply.offline), "an answer lost on the way"
    assert_equal :current, ask(server, first, again)
    assert_equal :entered, second.enter(text)
    assert_equal :current, ask(server, second, elsewhere)
    assert_equal :moved, ask(server, first, moving)
    refute_predicate first, :pro?
    assert_predicate second, :pro?
    [entering, checking, again, elsewhere, moving].each do |answered|
      verdict = answered.dig("reply", "body", "verdict")
      assert_equal answered["signed"], C.hex(C::SignedAnswers.verdict_message(verdict, C::LicenseKey.parse(text).id, nonce_of(answered)))
    end
  end

  # +license+ asks setdef's server what is due, with +exchange+'s nonce,
  # and hears the answer.
  def ask(server, license, exchange)
    nonce = nonce_of(exchange)
    due = license.due(nonce)
    license.heard(due, nonce, server.ask(due))
  end

  def play_friend_groups
    founder = session
    founder.create
    pump(founder)
    group = founder.groups.first
    assert_equal group.id, founder.take_arrival
    founder.game_finished(score: score_of("the founder's first game wins the vacant title"), sized_to_screen: true)
    pump(founder)
    assert_equal 1, founder.game_result.won
    assert_equal :you_won, founder.next_announcement.kind
    founder.report_achievements([body(exchange("the founder earns an achievement")).fetch("key")])
    pump(founder)
    founder.look_at(group.id)
    pump(founder)
    assert_equal %i[achievement title_change], founder.history(group.id).map { it.is_a?(Groups::TitleChange) ? :title_change : :achievement }

    newcomer = session
    newcomer.join(group.join_code)
    pump(newcomer)
    assert_equal [1, 2], newcomer.groups.first.members.map(&:number)
    newcomer.game_finished(score: score_of("a game short of the title"), sized_to_screen: true)
    pump(newcomer)
    assert_equal 3, newcomer.game_result.short
    newcomer.game_finished(score: score_of("a game that takes the title"), sized_to_screen: true)
    pump(newcomer)
    assert_equal :you_won, newcomer.next_announcement.kind
    founder.refresh
    pump(founder)
    assert_equal :you_lost, founder.next_announcement.kind
    newcomer.join(group.join_code)
    pump(newcomer)
    assert_equal :already_member, newcomer.error
    newcomer.join(body(exchange("a code that matches no group")).fetch("join_code"))
    pump(newcomer)
    assert_equal :no_such_group, newcomer.error
    newcomer.leave(group.id)
    pump(newcomer)
    assert_empty newcomer.groups
    newcomer.delete_everything
    pump(newcomer)
    refute_predicate newcomer, :known?

    refused = session
    refused.join(body(exchange("a full group refuses")).fetch("join_code"))
    pump(refused)
    assert_equal :group_full, refused.error
    refused.create
    pump(refused)
    assert_equal :group_limit, refused.error

    late = session
    late.create
    pump(late)
    assert_equal :too_many_tries, late.error
  end

  def play_themes
    asking = exchange("the themes a player who started on a date has")
    started_on = asking.dig("request", "path")[/started_on=([\d-]+)/, 1]
    themes = Themes.new
    feed = DotPopper::ThemeReleases.new(worker: InlineWorker.new(Network::Link.new(@url)), themes:,
                                        store: DotPopper::ScoreRecord::Memory.new, clock: -> { Time.utc(*started_on.split("-").map(&:to_i), 12) })
    feed.ask
    feed.update

    assert_equal asking.dig("reply", "body").map { it["key"] }, themes.keys
    refute_empty themes.keys
  end

  def session = Groups::Session.new(store: DotPopper::ScoreRecord::Memory.new, worker: InlineWorker.new(Network::Link.new(@url)))

  # Lets the whole conversation finish.
  def pump(session) = 6.times { session.update(quiet: true) }

  def exchange(name) = RECORD.fetch("exchanges").find { it["name"] == name } || flunk("no exchange named #{name}")
  def body(exchange) = exchange.dig("request", "body")
  def score_of(name) = body(exchange(name)).fetch("score")
  def nonce_of(exchange) = H[body(exchange).fetch("nonce")]

  def shape_problems(shape, value, path)
    text = ->(it) { it.is_a?(String) && !it.strip.empty? }
    case shape
    when Hash
      return ["#{path} should be an object"] unless value.is_a?(Hash)

      shape.flat_map { |key, inner| value.key?(key) ? shape_problems(inner, value[key], "#{path}.#{key}") : ["#{path}.#{key} is missing"] }
    when Array
      return ["#{path} should be a list"] unless value.is_a?(Array)
      return ["#{path} is empty"] if value.empty? && shape.first.is_a?(Hash)

      value.each_with_index.flat_map { |item, index| shape_problems(shape.first, item, "#{path}[#{index}]") }
    else
      fine = case shape
             when "text" then text.(value)
             when "true or false" then [true, false].include?(value)
             when "list" then value.is_a?(Array)
             when "hash_of_text" then value.is_a?(Hash) && value.values.all?(&text)
             when "hash_of_objects" then value.is_a?(Hash) && value.values.all?(Hash)
             when "label_or_null", "plain_or_null" then value.nil? || text.(value)
             when "withheld_or_null", "record_only_or_null"
               value.nil? || text.(value) || (value.is_a?(Hash) && %w[kind reason].all? { text.(value[it].to_s) })
             else flunk "the server's record names a shape this test does not know: #{shape}"
             end
      fine ? [] : ["#{path} should be #{shape}"]
    end
  end

  def serve
    loop do
      client = @server.accept
      head = +""
      head << client.gets until head.end_with?("\r\n\r\n")
      text = client.read(head[/content-length: (\d+)/i, 1].to_i)
      client.write(answer(head, text))
      client.close
    end
  end

  # The reply the record holds for the first exchange not yet made whose
  # request is exactly this one, or a 599 the game reads as no answer.
  def answer(head, text)
    method, path = head[/\A(\S+) (\S+)/, 1], head[/\A\S+ (\S+)/, 1]
    token = head[/^authorization: Bearer (.*?)\r$/i, 1]
    sent = { "method" => method, "path" => path, "token" => token, "body" => (JSON.parse(text) unless text.empty?) }
    found = @exchanges.find { !it["used"] && it["request"] == sent }
    return (@strangers << sent) && "HTTP/1.1 599 Unknown\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" unless found

    found["used"] = true
    reply = found["reply"]
    content = reply["body"].nil? ? "" : JSON.generate(reply["body"])
    retry_after = reply["retry_after"] ? "Retry-After: #{reply["retry_after"]}\r\n" : ""
    "HTTP/1.1 #{reply["status"]} Reply\r\nContent-Type: application/json\r\n#{retry_after}Content-Length: #{content.bytesize}\r\nConnection: close\r\n\r\n#{content}"
  end
end
