# frozen_string_literal: true

require "test_helper"

# Ed25519, setdef's certificates, license keys and signed answers, checked
# against the server's own test vector (docs/api.md, "Test vector") and the
# test keys.
class SignaturesTest < Minitest::Test
  C = DotPopper::Continuity
  H = ->(hex) { [hex].pack("H*") }

  # The server's published test vector, public values only.
  VECTOR_ROOT = H["7019dd39b840abc7e0f7fc22951b799d3a6b503e4425539bf64d0d2e28b677b4"]
  VECTOR_NONCE = H["000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"]
  VECTOR_PROOF = {
    "nonce" => "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    "signature" => "4523c24b7b106e8207bea434ddb355d0898f0c60a0edf8bc8593fd4f17ac9373f548ce3f7f5e96fd9f90ce455cdb93c196c4f1f96b82d7374ef7698dd2942004",
    "certificate" => "445043540169caa7e3cee69c41646f742d706f707065722f7365727665722d70726f6f662f76310000000000004b27a311e0ca69f749672766d988b3e673d347bfcd7f67aeff856ff743fe036d0f2371e812744e936b2ebfc4839dfba788620768c7f59020d77caee2d5c5dde9500c2f2769d3117d37e4e129268ddaae9cd8a9f4b89e1b54d3942af4ba58de01"
  }.freeze
  VECTOR_PINS = C::Pins.new(roots: [VECTOR_ROOT], license_keys: [])

  def test_openssl_verifies_ed25519_in_this_ruby
    assert C::Ed25519.verify(H["4b27a311e0ca69f749672766d988b3e673d347bfcd7f67aeff856ff743fe036d"],
                             H[VECTOR_PROOF["signature"]], C::SignedAnswers::PROOF + VECTOR_NONCE)
  end

  def test_this_ruby_has_ed25519
    assert_predicate C::Ed25519, :available?
  end

  def test_the_servers_test_vector_proves_itself
    assert C::SignedAnswers.proof?(VECTOR_PROOF, VECTOR_NONCE, VECTOR_PINS)
  end

  def test_a_proof_fails_for_another_nonce_root_or_any_changed_byte
    other = VECTOR_NONCE.dup.tap { it.setbyte(0, 9) }

    refute C::SignedAnswers.proof?(VECTOR_PROOF, other, VECTOR_PINS)
    refute C::SignedAnswers.proof?(VECTOR_PROOF, VECTOR_NONCE, C::TEST_PINS)
    %w[signature certificate].each do |field|
      changed = VECTOR_PROOF.merge(field => VECTOR_PROOF[field].sub(/.\z/) { it == "0" ? "1" : "0" })

      refute C::SignedAnswers.proof?(changed, VECTOR_NONCE, VECTOR_PINS), field
    end
    refute C::SignedAnswers.proof?({}, VECTOR_NONCE, VECTOR_PINS)
    refute C::SignedAnswers.proof?("<html>", VECTOR_NONCE, VECTOR_PINS)
  end

  def test_the_fakes_proof_verifies_against_the_test_pins_only
    nonce = C::SignedAnswers.fresh

    assert C::SignedAnswers.proof?(C::SignedAnswers.signed_proof(nonce), nonce, C::TEST_PINS)
    refute C::SignedAnswers.proof?(C::SignedAnswers.signed_proof(nonce), nonce, VECTOR_PINS)
  end

  def test_a_certificate_for_another_purpose_is_refused
    certificate = C::Certificate.issue(C::TestKeys::ROOT, C.label("dot-popper/other/v1"), C::Ed25519.public_key(C::TestKeys::ONLINE))

    refute_nil C::Certificate.verified(C::TestKeys.online_certificate, roots: C::TEST_PINS.roots, purpose: C::Certificate::PROOF)
    assert_nil C::Certificate.verified(certificate, roots: C::TEST_PINS.roots, purpose: C::Certificate::PROOF)
  end

  def test_a_license_key_reads_back_from_its_text_however_it_was_pasted
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)
    text = key.text

    assert_match(/\ADP-(?:[0-9A-Z]{5}-){25}[0-9A-Z]{5}\z/, text)
    assert_equal key, C::LicenseKey.parse(text)
    assert_equal key, C::LicenseKey.parse("  #{text.downcase.delete("-").scan(/.{1,40}/).join("\r\n")}\n")
    assert_equal key, C::LicenseKey.parse(text.delete_prefix("DP-").tr("0", "O"))
    assert key.valid?(C::TEST_PINS)
  end

  def test_a_key_not_signed_by_a_pinned_license_key_or_changed_is_not_valid
    stranger = C::LicenseKey.issue(C::TestKeys::ONLINE)
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)
    changed = key.with(id: key.id.dup.tap { it.setbyte(0, key.id.getbyte(0) ^ 1) })

    refute stranger.valid?(C::TEST_PINS)
    refute changed.valid?(C::TEST_PINS)
    refute key.valid?(VECTOR_PINS)
  end

  def test_text_that_is_no_key_parses_to_nothing
    key = C::LicenseKey.issue(C::TestKeys::LICENSE)

    ["", "hello", "A" * 130, "U" * 130, nil, key.text.sub(/.\z/, "Z"), key.text[0..-2]].each { assert_nil C::LicenseKey.parse(it) }
  end

  def test_a_verdict_is_read_only_for_its_key_and_nonce
    id = Random.bytes(16)
    nonce = C::SignedAnswers.fresh
    body = C::SignedAnswers.signed_verdict("moved", id, nonce)

    assert_equal :moved, C::SignedAnswers.verdict(body, id, nonce, C::TEST_PINS)
    assert_equal :current, C::SignedAnswers.verdict(C::SignedAnswers.signed_verdict("current", id, nonce), id, nonce, C::TEST_PINS)
    assert_nil C::SignedAnswers.verdict(body, id, C::SignedAnswers.fresh, C::TEST_PINS)
    assert_nil C::SignedAnswers.verdict(body, Random.bytes(16), nonce, C::TEST_PINS)
    assert_nil C::SignedAnswers.verdict(body.merge("verdict" => "current"), id, nonce, C::TEST_PINS)
    assert_nil C::SignedAnswers.verdict(body, id, nonce, VECTOR_PINS)
  end

  def test_a_store_build_pins_setdefs_real_keys_and_so_asks_the_real_server
    assert_same C::SETDEF_PINS, C::PINNED
    assert C.live?
    refute C.live?(C::TEST_PINS)
    assert_equal %w[8336ad85d326749b ad88ca8070d052b7], C::PINNED.roots.map { C.hex(C::Certificate.id_of(it)) }
    assert_equal [2, 2], [C::PINNED.roots.size, C::PINNED.license_keys.size]
    assert(([*C::PINNED.roots, *C::PINNED.license_keys] & [*C::TEST_PINS.roots, *C::TEST_PINS.license_keys]).empty?)
    assert(([*C::PINNED.roots, *C::PINNED.license_keys]).all? { it.bytesize == 32 })
  end

  def test_nothing_the_test_build_signs_passes_against_the_real_pins
    assert C::LicenseKey.issue(C::TestKeys::LICENSE).valid?(C::TEST_PINS)
    refute C::LicenseKey.issue(C::TestKeys::LICENSE).valid?(C::PINNED)
    nonce = C::SignedAnswers.fresh
    assert C::SignedAnswers.proof?(C::SignedAnswers.signed_proof(nonce), nonce, C::TEST_PINS)
    refute C::SignedAnswers.proof?(C::SignedAnswers.signed_proof(nonce), nonce, C::PINNED)
  end

  # The server's license-key test vector signs with RFC 8032's first test
  # key, which is public and pinned by no build.
  def test_the_server_license_key_test_vector_is_not_valid_against_the_real_pins
    vector = C::LicenseKey.parse("DP-04002-0G30G-2GC1R-81450-P30D1-R7SFX-0HGSD-6SGPK-K2W19-V4W1S-HG83P-HYKNB-CE1KN-Q1F61-356YC-HEY9G-RB61G-ZG7MQ-0YPZS-A2015-PT5GT-M3X50-KSA5M-FC841-KPZC6-WXQ0W")

    assert_equal H["000102030405060708090a0b0c0d0e0f"], vector.id
    assert vector.valid?(C::Pins.new(roots: [], license_keys: [H["d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"]]))
    refute vector.valid?(C::PINNED)
  end
end
