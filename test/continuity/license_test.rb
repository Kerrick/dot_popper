# frozen_string_literal: true

require "test_helper"
require "uri"

# One key, one device at a time, and the one test of whether setdef is
# gone, played against the test build's fake server and fakes of the ports.
class LicenseTest < Minitest::Test
  C = DotPopper::Continuity
  Memory = DotPopper::ScoreRecord::Memory
  Reply = DotPopper::Network::Reply
  TODAY = Date.new(2026, 11, 9)

  def setup
    @ledger = Memory.new
    @key = C::LicenseKey.issue(C::TestKeys::LICENSE)
  end

  # A device: its saved license, gone-ness and a watch over +server+.
  def device(server = C::FakeSetdef.new(@ledger), connectivity: server, today: TODAY)
    license = C::License.new(Memory.new, pins: C::TEST_PINS)
    C::Watch.new(server:, connectivity:, gone: C::Gone.new(Memory.new), license:, today: -> { today }, pins: C::TEST_PINS)
  end

  def run_check(watch)
    watch.start
    watch.join
    watch.update
    watch.verdict
  end

  # The keys a build trusts, by its channel alone: setdef's in a store
  # build, the test keys in a test build (ADR-0010).
  def test_a_build_trusts_setdefs_keys_by_its_channel_alone
    assert_same C::TEST_PINS, C.pins_for(nil)
    DotPopper::Build::CHANNEL_NAMES.each { assert_same C::PINNED, C.pins_for(it), it }
    refute @key.valid?(C.pins_for(DotPopper::Build::WEBSITE))
    assert @key.valid?(C.pins_for(nil))
  end

  # An app store's build never reads license.txt, so a key left on disk
  # grants nothing and is never sent; the website's and a test build keep it.
  def test_only_a_build_that_takes_license_keys_keeps_one_in_license_txt
    files = Hash.new { |all, name| all[name] = Memory.new }
    file = ->(name) { files[name] }
    DotPopper::Build::STORES.each do |channel|
      kept = C::License.kept_in(channel, file)

      assert_instance_of Memory, kept, channel
      refute_same files["license.txt"], kept, channel
    end
    [DotPopper::Build::WEBSITE, nil].each { assert_same files["license.txt"], C::License.kept_in(it, file), it.inspect }
  end

  def test_a_valid_key_is_pro_at_once_offline_and_a_bad_one_is_refused
    license = C::License.new(Memory.new, pins: C::TEST_PINS)

    assert_equal :invalid, license.enter("DP-NOT-A-KEY")
    assert_equal :invalid, license.enter(C::LicenseKey.issue(C::TestKeys::ONLINE).text)
    refute license.pro?
    assert_equal :entered, license.enter(@key.text)
    assert license.pro?
    assert_equal :same, license.enter(@key.text.downcase)
  end

  # The maintainer's rule: editing a text file must never grant Pro. The
  # saved key is verified again at each launch, offline.
  def test_license_txt_is_pro_only_while_it_holds_a_key_that_verifies
    saved = Memory.new
    C::License.new(saved, pins: C::TEST_PINS).enter(@key.text)

    assert_predicate C::License.new(Memory.new(saved.read), pins: C::TEST_PINS), :pro?, "a relaunch, offline"
    refute_predicate C::License.new(Memory.new(saved.read), pins: C::PINNED), :pro?, "a store build"
    ["key: pro\n", "pro: yes\nregistered: yes\n", "key: #{@key.text.sub(/.\z/) { it == "0" ? "1" : "0" }}\n", "4"].each do |text|
      refute_predicate C::License.new(Memory.new(text), pins: C::TEST_PINS), :pro?, text
    end
  end

  def test_entering_a_key_registers_it_and_checks_keep_it_current
    watch = device
    watch.license.enter(@key.text)

    assert_equal :current, run_check(watch)
    assert_predicate watch.license, :registered?
    3.times { assert_equal :current, run_check(watch) }
    assert_predicate watch.license, :pro?
  end

  def test_a_key_entered_on_another_device_returns_the_first_to_free_on_a_signed_answer
    first = device
    first.license.enter(@key.text)
    run_check(first)
    second = device
    second.license.enter(@key.text)
    run_check(second)

    assert_equal :moved, run_check(first)
    refute_predicate first.license, :pro?
    assert_equal :current, run_check(second)
  end

  def test_no_answer_a_refusal_or_a_wrongly_signed_moved_never_removes_pro
    watch = device
    watch.license.enter(@key.text)
    run_check(watch)
    forged = Object.new
    def forged.proof(nonce) = Reply.new(status: 200, body: C::SignedAnswers.signed_proof(nonce))
    def forged.ask(due) = Reply.new(status: 200, body: { "key_id" => due.body[:key_id], "verdict" => "moved", "nonce" => due.body[:nonce], "signature" => "00" * 64, "certificate" => C.hex(C::TestKeys.online_certificate) })
    refusing = Object.new
    def refusing.proof(nonce) = Reply.new(status: 200, body: C::SignedAnswers.signed_proof(nonce))
    def refusing.ask(_due) = Reply.new(status: 500, body: {})

    [forged, refusing, C::FakeSetdef.new(@ledger, mode: :offline), C::FakeSetdef.new(@ledger, mode: :gone)].each do |server|
      other = C::Watch.new(server:, connectivity: server.respond_to?(:online?) ? server : C::FakeSetdef.new(@ledger),
                           gone: C::Gone.new(Memory.new), license: watch.license, today: -> { TODAY }, pins: C::TEST_PINS)
      run_check(other)

      assert_predicate watch.license, :pro?
    end
  end

  def test_a_check_whose_answer_was_lost_is_retried_with_the_same_secrets
    watch = device
    watch.license.enter(@key.text)
    run_check(watch)
    due = watch.license.due(C::SignedAnswers.fresh)
    C::FakeSetdef.new(@ledger).ask(due) # the server took it, and the answer was lost

    assert_equal due.body[:next], watch.license.due(C::SignedAnswers.fresh).body[:next]
    assert_equal :current, run_check(watch)
    assert_equal :current, run_check(watch)
  end

  def test_setdef_is_gone_only_with_no_proof_while_the_internet_works
    here = device
    gone = device(C::FakeSetdef.new(@ledger, mode: :gone))
    offline = device(C::FakeSetdef.new(@ledger, mode: :offline))
    [here, gone, offline].each { run_check(it) }

    refute_predicate here.gone, :gone?
    assert_equal TODAY, gone.gone.since
    refute_predicate offline.gone, :gone?
  end

  def test_each_answer_says_whether_setdef_is_gone_or_here
    gone = C::Gone.new(Memory.new)
    heard = []
    gone.subscribe(->(event) { heard << event })
    gone.heard(:unknown, TODAY)
    gone.heard(:gone, TODAY + 1)
    gone.heard(:unknown, TODAY + 4)
    gone.heard(:here, TODAY + 5)

    assert_equal [C::SetdefGone.new(since: TODAY + 1, today: TODAY + 1), C::SetdefGone.new(since: TODAY + 1, today: TODAY + 4), C::SetdefHere.new], heard
    assert_equal 3, heard[1].days
  end

  def test_gone_lasts_through_no_internet_and_ends_when_setdef_proves_itself
    store = Memory.new
    gone = C::Gone.new(store)
    gone.heard(:gone, TODAY)
    gone.heard(:gone, TODAY + 3)
    gone.heard(:unknown, TODAY + 9)

    assert_equal 9, gone.days(TODAY + 9)
    gone.heard(:here, TODAY + 10)

    refute_predicate gone, :gone?
    assert_equal 0, gone.days(TODAY + 10)
  end

  def test_while_setdef_is_gone_a_key_works_at_once_and_registers_once_it_answers
    ledger_server = C::FakeSetdef.new(@ledger, mode: :gone)
    watch = device(ledger_server)
    watch.license.enter(@key.text)
    run_check(watch)

    assert_predicate watch.license, :pro?
    refute_predicate watch.license, :registered?
    back = C::Watch.new(server: C::FakeSetdef.new(@ledger), connectivity: ledger_server, gone: watch.gone, license: watch.license,
                        today: -> { TODAY }, pins: C::TEST_PINS)
    run_check(back)

    assert_predicate watch.license, :registered?
    refute_predicate watch.gone, :gone?
  end

  def test_the_connectivity_checks_need_their_expected_answers
    answers = { "captive.apple.com" => Reply.new(status: 200, body: "<HTML>Captive</HTML>"),
                "connectivitycheck.gstatic.com" => Reply.new(status: 200, body: "portal"),
                "www.msftconnecttest.com" => Reply.new(status: 200, body: "Microsoft Connect Test") }
    asked = []
    link = lambda do |url|
      host = URI(url).host
      Object.new.tap { |l| l.define_singleton_method(:call) { |*_| (asked << host) && answers.fetch(host) } }
    end

    assert C::Connectivity.new(link:).online?
    assert_equal answers.keys, asked
    answers["www.msftconnecttest.com"] = Reply.offline

    refute C::Connectivity.new(link:).online?
  end
end
