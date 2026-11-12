# frozen_string_literal: true

require_relative "test_helper"
require "openssl"
require "json"

# A store's receipt is checked by the game itself, offline: Play's signed
# purchase and StoreKit 2's signed transaction (ADR-0010). Apple's real chain cannot be made here, so its
# check runs against a chain this test makes with Apple's markings, and
# against Apple's real root only to show that chain is refused there.
class ReceiptTest < Minitest::Test
  Receipt = DotPopper::Receipt
  TEST = Receipt::TEST

  # Play

  def test_the_fake_stores_receipt_proves_pro_in_a_test_build_only
    receipt = Receipt.issue

    assert Receipt.valid?(receipt, TEST)
    refute Receipt.valid?(receipt, Receipt::STORES)
  end

  def test_an_edited_play_purchase_does_not_verify
    _, json64, signature = Receipt.issue.split(":")
    json = json64.unpack1("m").sub("TEST.", "TEST.0")

    refute Receipt.valid?("play:#{[json].pack("m0")}:#{signature}", TEST)
  end

  def test_a_play_purchase_for_another_app_or_product_or_still_pending_proves_nothing
    refute Receipt.valid?(Receipt.issue(app_id: "com.example.Other"), TEST)
    refute Receipt.valid?(Receipt.issue(product_id: "com.setdef.DotPopper.other"), TEST)
    refute Receipt.valid?(Receipt.issue(state: 4), TEST)
  end

  def test_a_play_purchase_signed_by_any_other_key_proves_nothing
    refute Receipt.valid?(Receipt.issue(key: OpenSSL::PKey::RSA.generate(2048).to_pem), TEST)
  end

  def test_a_store_build_pins_apples_root
    root = OpenSSL::X509::Certificate.new(Receipt::APPLE_ROOT_G3)

    assert_equal "Apple Root CA - G3", root.subject.to_a.assoc("CN")[1]
    assert_equal "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179", OpenSSL::Digest::SHA256.hexdigest(root.to_der)
  end

  # The Microsoft Store

  def test_windows_word_proves_pro_only_in_the_microsoft_store_build
    word = "microsoft:#{Receipt::PRODUCT_ID}:9NBLGGH4R315/000N"

    assert Receipt.valid?(word, Receipt::MICROSOFT_STORE)
    refute Receipt.valid?(word, Receipt::STORES)
    refute Receipt.valid?(word, TEST)
  end

  def test_windows_word_for_another_add_on_or_no_sku_proves_nothing
    refute Receipt.valid?("microsoft:com.setdef.DotPopper.other:9NBLGGH4R315/000N", Receipt::MICROSOFT_STORE)
    refute Receipt.valid?("microsoft:#{Receipt::PRODUCT_ID}", Receipt::MICROSOFT_STORE)
    refute Receipt.valid?("microsoft:#{Receipt::PRODUCT_ID}:owned", Receipt::MICROSOFT_STORE)
  end

  def test_the_microsoft_store_build_takes_no_signed_receipt_from_another_store
    refute Receipt.valid?(Receipt.issue, Receipt::MICROSOFT_STORE)
    refute Receipt.valid?(apple, Receipt::MICROSOFT_STORE)
  end

  # The App Store

  def test_a_transaction_chained_to_a_pinned_root_proves_pro
    assert Receipt.valid?(apple, trust)
  end

  def test_a_transaction_chained_to_any_root_but_apples_proves_nothing_in_a_store_build
    refute Receipt.valid?(apple, Receipt::STORES)
    refute Receipt.valid?(apple, TEST)
  end

  def test_an_edited_transaction_does_not_verify
    head, body, signature = apple.delete_prefix("apple:").split(".")
    edited = JSON.parse(decode(body)).merge("productId" => "com.setdef.DotPopper.pro ").to_json

    refute Receipt.valid?("apple:#{head}.#{encode(edited)}.#{signature}", trust)
  end

  def test_a_transaction_for_another_app_or_product_or_revoked_proves_nothing
    refute Receipt.valid?(apple(bundleId: "com.example.Other"), trust)
    refute Receipt.valid?(apple(productId: "com.setdef.DotPopper.other"), trust)
    refute Receipt.valid?(apple(revocationDate: 1_700_000_000_000), trust)
  end

  def test_a_chain_without_apples_markings_proves_nothing
    refute Receipt.valid?(apple(marked: false), trust)
  end

  def test_a_transaction_signed_outside_its_certificates_lifetime_proves_nothing
    refute Receipt.valid?(apple(signedDate: ((Time.now + (3 * 365 * 86_400)).to_f * 1000).to_i), trust)
  end

  private

  def trust = Receipt::Trust.new(apple_roots: [chain[:root].to_der], play_keys: [], app_id: Receipt::APP_ID, product_id: Receipt::PRODUCT_ID,
                                     windows_license: false)

  # A root, an intermediate and a leaf, as Apple's are laid out.
  def chain
    @chain ||= begin
      root_key = OpenSSL::PKey::EC.generate("secp384r1")
      root = certificate("Test Root", root_key, root_key, nil, ca: true)
      middle_key = OpenSSL::PKey::EC.generate("prime256v1")
      leaf_key = OpenSSL::PKey::EC.generate("prime256v1")
      { root:, leaf_key:, middle: ->(marked) { certificate("Test WWDR", middle_key, root_key, root, ca: true, oid: (Receipt::Apple::INTERMEDIATE if marked)) },
        leaf: ->(marked, middle) { certificate("Test Signing", leaf_key, middle_key, middle, oid: (Receipt::Apple::LEAF if marked)) } }
    end
  end

  def certificate(name, key, signer, issuer, ca: false, oid: nil)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = Random.rand(1 << 32)
    cert.subject = OpenSSL::X509::Name.parse("/CN=#{name}")
    cert.issuer = issuer ? issuer.subject : cert.subject
    cert.public_key = key
    cert.not_before = Time.now - 86_400
    cert.not_after = Time.now + (365 * 86_400)
    factory = OpenSSL::X509::ExtensionFactory.new(issuer || cert, cert)
    cert.add_extension(factory.create_extension("basicConstraints", ca ? "CA:TRUE" : "CA:FALSE", true))
    cert.add_extension(factory.create_extension("keyUsage", ca ? "keyCertSign,cRLSign" : "digitalSignature", true))
    cert.add_extension(OpenSSL::X509::Extension.new(oid, OpenSSL::ASN1::Null.new(nil).to_der)) if oid
    cert.sign(signer, "SHA256")
    cert
  end

  def apple(marked: true, **changes)
    middle = chain[:middle].call(marked)
    leaf = chain[:leaf].call(marked, middle)
    header = { alg: "ES256", x5c: [leaf, middle, chain[:root]].map { [it.to_der].pack("m0") } }
    body = { transactionId: "2000000000000001", bundleId: Receipt::APP_ID, productId: Receipt::PRODUCT_ID,
             signedDate: (Time.now.to_f * 1000).to_i, environment: "Sandbox" }.merge(changes).compact
    input = "#{encode(header.to_json)}.#{encode(body.to_json)}"
    der = chain[:leaf_key].sign("SHA256", input)
    raw = OpenSSL::ASN1.decode(der).value.map { it.value.to_s(2).rjust(32, "\0") }.join
    "apple:#{input}.#{encode(raw)}"
  end

  def encode(bytes) = [bytes].pack("m0").tr("+/", "-_").delete("=")
  def decode(text) = text.tr("-_", "+/").then { it + ("=" * (-it.size % 4)) }.unpack1("m")
end
