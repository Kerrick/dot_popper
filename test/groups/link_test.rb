# frozen_string_literal: true

require "test_helper"
require "socket"

class LinkTest < Minitest::Test
  Groups = DotPopper::Groups

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
          http("200 OK", '[{"id":7,"thief_seat":3,"score":41}]'),
          http("204 No Content", "")) do |url|
      link = Groups::Link.new(url)
      limited = link.call(:post, "/group", { seat: 1 }, "t")

      assert_equal [429, { "error" => "rate_limited" }, 90], [limited.status, limited.body, limited.retry_after]
      thefts = link.call(:get, "/group/thefts", nil, "t")

      assert_equal [{ "id" => 7, "thief_seat" => 3, "score" => 41 }], thefts.body
      assert_nil thefts.retry_after
      assert_predicate link.call(:delete, "/group/thefts/7", nil, "t"), :ok?
    end
    assert_match(%r{\APOST /group }, @requests.first)
    assert_match(/authorization: Bearer t/i, @requests.first)
  end

  def test_nothing_listening_is_offline
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    assert_predicate Groups::Link.new("http://127.0.0.1:#{port}").call(:get, "/group", nil, "t"), :offline?
  end
end
