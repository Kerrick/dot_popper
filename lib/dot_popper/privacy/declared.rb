# frozen_string_literal: true

module DotPopper
  # What the game declares about the player's data, in one place, each list
  # compared exactly with what it declares by test/privacy: Gemfile.lock,
  # the Android build and manifest, the iOS plists. A new SDK, permission,
  # save file or network call fails `bundle exec rake` until it is declared
  # here, and doc/privacy.json is generated from these (Privacy::Document).
  module Privacy
    # A library or fact a player is told in +plain+ words, or one kept
    # +record_only+, with why it is not for them. One of the two is required.
    class Item < Data.define(:note, :plain, :record_only)
      def initialize(note:, plain: nil, record_only: nil)
        raise ArgumentError, "#{note} needs plain words or a record_only reason, not both" if plain.nil? == record_only.nil?

        super
      end
    end

    ENGINE = "It is the game's own engine, and reaches no outside service."

    # The gems that ship in a built app: Gemfile.lock, less the development
    # and test groups, which Fledge leaves out.
    SHIPPED_GEMS = { "lota" => Item.new(note: "the game engine: draws, plays sound, reads input", record_only: ENGINE) }.freeze

    # Android build.gradle's dependencies. Billing's version is exact on
    # purpose: a new one can merge in new permissions (ANDROID_MERGED).
    ANDROID_DEPENDENCIES = {
      "files('libs/FledgeRuby.aar')" => Item.new(note: "runs the game's Ruby", record_only: ENGINE),
      "com.android.billingclient:billing:9.1.0" => Item.new(note: "Google Play Billing, to buy Pro", plain: "On Android, Google Play handles buying Pro.")
    }.freeze

    IOS_FRAMEWORKS = Item.new(note: "None beyond Apple's frameworks, StoreKit among them.", plain: "On iPhone and iPad, Apple handles buying Pro.")

    # android/host's manifest, exactly. What INTERNET is for follows what
    # this build really reaches the server for.
    ANDROID_PERMISSIONS = {
      "android.permission.INTERNET" => "to reach the game's server for #{Groups.features_built.join(" and ")}",
      "android.permission.VIBRATE" => "for haptic feedback"
    }.freeze

    # Added by a library's own manifest when Android merges it in, so they
    # are not in android/host's. Read from billing 9.1.0's AAR by hand.
    ANDROID_MERGED = { "com.android.vending.BILLING" => "added by Play Billing, to buy Pro" }.freeze

    # NS*UsageDescription keys in the iOS Info.plist: permissions asked of
    # the player. The game asks for none.
    IOS_USAGE_STRINGS = {}.freeze

    # What each kind of data sent counts as on the stores' privacy labels.
    STORE_LABELS = {
      gameplay_content: { apple: "NSPrivacyCollectedDataTypeGameplayContent", apple_name: "Gameplay Content", apple_linked: true,
                          google: "App activity > Other actions", google_optional: true,
                          why_linked: "the server keeps scores under the player's token" },
      user_id: { apple: "NSPrivacyCollectedDataTypeUserID", apple_name: "User ID", apple_linked: true,
                 google: "Personal info > User IDs", google_optional: true,
                 why_linked: "it is the identifier the scores are linked by" },
      other_usage: { apple: "NSPrivacyCollectedDataTypeOtherUsageData", apple_name: "Other Usage Data", apple_linked: false,
                     google: "App activity > App interactions", google_optional: false,
                     why_linked: "no token is sent with it" }
    }.freeze

    # PrivacyInfo.xcprivacy, apart from the data types STORE_LABELS gives.
    APPLE_TRACKING = false
    APPLE_TRACKING_DOMAINS = [].freeze
    APPLE_PURPOSE = "NSPrivacyCollectedDataTypePurposeAppFunctionality"
    APPLE_APIS = { "NSPrivacyAccessedAPICategoryFileTimestamp" => ["C617.1"],
                   "NSPrivacyAccessedAPICategorySystemBootTime" => ["35F9.1"] }.freeze

    # The address the server sees is the one thing it learns that no
    # Request sends as a field, so it is stated here, for the labels.
    IP_ADDRESSES = "The server's proxy and request log see the IP address of every request, and its rate-limit notes can hold it. " \
                   "The game neither reads nor sends it as data, and it is not used to work out a location. " \
                   "How long each is kept is stated by the server's own privacy policy.".freeze

    SENSOR = "The game reads your device's tilt only on the Game Over screen, to roll the dots. It never stores or sends that."
    NO_OUTSIDE_SERVICES = "The game has no analytics, crash-reporting, advertising or attribution services."
    PURCHASES = "When you buy Pro, your purchase goes straight from your device to Apple or Google. The game sends nothing about it."

    # What the code here cannot make true, said plainly.
    NOT_ENFORCED = [
      Item.new(note: "What Apple and Google do with a purchase: it goes straight from the device to their store, in the iOS and Android hosts.",
               plain: "Apple and Google handle your purchase under their own privacy terms."),
      Item.new(note: "How the iOS and Android hosts, and the operating system's share sheet, behave beyond what their source shows: no test here runs them.",
               plain: "When you share a result, your device's own sharing screen takes over. We can't see what happens next."),
      Item.new(note: "What Lota, LÖVE, SDL and Fledge's runtime do inside the app: audited by hand for their required-reason APIs, not by a test.",
               record_only: "A note for developers about how the game is built."),
      Item.new(note: "Permissions a library's own manifest adds when Android merges it in: ANDROID_MERGED records what billing 9.1.0's manifest says, and its transitive libraries are unchecked. Read the merged manifest of a release build.",
               record_only: "A release checklist item for developers."),
      Item.new(note: "That a store's label definitions still fit these answers: Apple and Google change them, so re-read them when entering.",
               record_only: "A note for whoever fills in the store forms.")
    ].freeze
  end
end
