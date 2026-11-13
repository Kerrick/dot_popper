# frozen_string_literal: true

require "test_helper"
require "socket"

class LinkTest < Minitest::Test
  Network = DotPopper::Network

  # A job from a declaration of this test's own.
  def job(verb, path, body = nil)
    fields = body.to_h.keys.to_h { [it, Network::Field.new(what: it.to_s, label: :gameplay_content)] }
    Network::Job.of(Network::Request.new(kind: :tried, verb:, path:, body: fields, happens: "In this test.", feature: "tests"), body:)
  end

  # Serves each canned response once, to one request apiece, on a port of
  # this machine's own, and keeps what it was asked.
  def serve(*responses)
    server = TCPServer.new("127.0.0.1", 0)
    @requests = []
    thread = Thread.new do
      responses.each do |response|
        client = server.accept
        head = +""
        head << client.gets until head.end_with?("\r\n\r\n")
        client.read(head[/content-length: (\d+)/i, 1].to_i)
        @requests << head
        client.write(response)
        client.close
      end
    end
    yield "http://127.0.0.1:#{server.addr[1]}"
  ensure
    thread&.join(2)
    server&.close
  end

  def http(status, body, headers = {})
    extra = headers.map { "#{_1}: #{_2}\r\n" }.join
    "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n#{extra}Connection: close\r\n\r\n#{body}"
  end

  def test_a_429_carries_its_retry_after_and_an_array_body_is_kept
    serve(http("429 Too Many Requests", '{"error":"rate_limited"}', "Retry-After" => "90"),
          http("200 OK", '[{"id":7,"champion_number":3,"score":41}]'),
          http("204 No Content", "")) do |url|
      link = Network::Link.new(url)
      limited = link.call(job(:post, "/group", { seat: 1 }), "t")

      assert_equal [429, { "error" => "rate_limited" }, 90], [limited.status, limited.body, limited.retry_after]
      changes = link.call(job(:get, "/groups/1/title_changes"), "t")

      assert_equal [{ "id" => 7, "champion_number" => 3, "score" => 41 }], changes.body
      assert_nil changes.retry_after
      assert_predicate link.call(job(:delete, "/groups/1/membership"), "t"), :ok?
    end
    assert_match(%r{\APOST /group }, @requests.first)
    assert_match(/authorization: Bearer t/i, @requests.first)
  end

  def test_nothing_listening_is_offline
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    assert_predicate Network::Link.new("http://127.0.0.1:#{port}").call(job(:get, "/group"), "t"), :offline?
  end
end
