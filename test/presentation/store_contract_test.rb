# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "store_contract"
require "dot_popper/shell/store_answers"
require "tmpdir"

# The one contract, run against each adapter behind Storefront's port.
class FakeStoreContractTest < Minitest::Test
  include StoreContract

  FakeStore = DotPopper::Presentation::FakeStore

  def new_store(fails: nil, ledger: DotPopper::ScoreRecord::Memory.new)
    FakeStore.new(ledger, fails:).tap { (@ledgers ||= {})[it] = ledger }
  end

  def relaunched(store) = new_store(ledger: @ledgers.fetch(store))

  # The maintainer's rule: editing a text file must never grant Pro.
  def test_a_ledger_edited_to_say_owned_proves_nothing
    ledger = DotPopper::ScoreRecord::Memory.new
    ledger.write("owned")
    entitlement = DotPopper::Entitlement.test
    front = Storefront.new(port: new_store(ledger:), entitlement:)
    front.connect
    settle(front) { front.price }
    3.times { front.update(Storefront::EVERY) }

    refute_predicate entitlement, :pro?
  end

  # A playtester's pretend Pro was bought before Pro's product id was
  # lowercased; it still owns Pro, under today's id.
  def test_a_pretend_purchase_under_the_earlier_product_id_carries_over
    ledger = DotPopper::ScoreRecord::Memory.new
    ledger.write(DotPopper::Receipt.issue(product_id: "com.setdef.DotPopper.pro"))
    entitlement = DotPopper::Entitlement.test
    front = Storefront.new(port: new_store(ledger:), entitlement:)
    front.connect
    settle(front) { front.price }
    3.times { front.update(Storefront::EVERY) }

    assert_predicate entitlement, :pro?
    assert DotPopper::Receipt.valid?(ledger.read, DotPopper::Receipt::TEST)
  end

  def test_a_failure_is_for_a_developers_setting_only
    assert_nil FakeStore.failure({})
    assert_nil FakeStore.failure({ "DOT_POPPER_FAKE_STORE_FAILS" => "nonsense" })
    assert_equal "pending", FakeStore.failure({ "DOT_POPPER_FAKE_STORE_FAILS" => "pending" })
  end
end

# The NativeStore adapter, with a real answer file and a stand-in for the
# app's host, written from Store.swift and ProStore.java. It runs the
# contract over the game's half of the native path. It cannot show that
# the host's real half behaves like this (ADR-0009).
class NativeStoreContractTest < Minitest::Test
  include StoreContract

  # Takes a dotpopper-store: URL and writes the answer as the hosts do:
  # "loading" or "working" at once, the outcome on the next read.
  class HostStandIn
    attr_accessor :owned

    def initialize(fails, path)
      @fails = fails
      @path = path
      @price = ""
      @owned = false
      @receipt = DotPopper::Receipt.issue
    end

    def open(url)
      return false if @fails == "refused"

      @action = url[%r{://(\w+)}, 1]
      @number = url[/[?&]n=(\d+)/, 1]
      write(@action == "open" ? "loading" : "working")
      @due = true
      true
    end

    # What the host would by now have rewritten the file to.
    def advance
      return unless @due

      @due = false
      write(outcome)
    end

    private

    def outcome
      return "unavailable" if @fails == "unavailable"

      send(:"on_#{@action}")
    end

    def on_open
      @price = "$1.99"
      "ready"
    end

    def on_buy
      return "failed" if @price.empty?
      return @fails if @fails

      @owned = true
      "ready"
    end

    def on_restore
      return @fails if %w[failed canceled].include?(@fails)

      @owned ? "restored" : "none"
    end

    def write(state)
      File.write(@path, "answer=#{@number}\nowned=#{@owned ? 1 : 0}\nstate=#{state}\nprice=#{@price}\n#{"receipt=#{@receipt}\n" if @owned}")
    end
  end

  # The file, with the host catching up as the game reads it.
  class Polled < Data.define(:file, :host)
    def read = file.read.tap { host.advance }
    def remove = file.remove
    def path = file.path
  end

  def setup
    super
    @folder = Dir.mktmpdir("dot_popper_store")
    @count = 0
  end

  def teardown = FileUtils.rm_rf(@folder)

  def new_store(fails: nil)
    @count += 1
    path = File.join(@folder, "#{@count}.txt")
    host = HostStandIn.new(fails, path)
    (@hosts ||= {})[path] = host
    DotPopper::Presentation::NativeStore.new(opener: host, answers: Polled.new(file: DotPopper::Shell::StoreAnswers.new(path:), host:))
  end

  def relaunched(store)
    owned = @hosts.fetch(store.path).owned
    new_store.tap { @hosts.fetch(it.path).owned = owned }
  end
end
