# frozen_string_literal: true

module DotPopper
  # What the game declares about the player's data, in one place, each list
  # compared exactly with what it declares by test/privacy: Gemfile.lock,
  # the Android build and manifest, the iOS plists. A new SDK, permission,
  # save file or network call fails `bundle exec rake` until it is declared
  # here, and doc/privacy.json is generated from these (Privacy::Document).
  module Privacy
    # The gems that ship in a built app: Gemfile.lock, less the development
    # and test groups, which Fledge leaves out.
    SHIPPED_GEMS = { "lota" => "the game engine: draws, plays sound, reads input" }.freeze

    # Android build.gradle's dependencies. Billing's version is exact on
    # purpose: a new one can merge in new permissions (ANDROID_MERGED).
    ANDROID_DEPENDENCIES = {
      "files('libs/FledgeRuby.aar')" => "runs the game's Ruby",
      "com.android.billingclient:billing:9.1.0" => "Google Play Billing, to buy Pro"
    }.freeze

    # android/host's manifest, exactly.
    ANDROID_PERMISSIONS = {
      "android.permission.INTERNET" => "to reach the friend-group and themes server",
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

    SENSOR = "The accelerometer is read only while the game-over pile is on screen, to tilt the dots. It is neither stored nor sent."
    NO_OUTSIDE_SERVICES = "The game has no analytics, crash-reporting, advertising or attribution services."

    # What the code here cannot make true, said plainly.
    NOT_ENFORCED = [
      "What Apple and Google do with a purchase: it goes straight from the device to their store, in the iOS and Android hosts, and this game's server never sees it.",
      "How the iOS and Android hosts, and the operating system's share sheet, behave beyond what their source shows: no test here runs them.",
      "What Lota, LÖVE, SDL and Fledge's runtime do inside the app: audited by hand for their required-reason APIs, not by a test.",
      "Permissions a library's own manifest adds when Android merges it in: ANDROID_MERGED records what billing 9.1.0's manifest says, and its transitive libraries are unchecked. Read the merged manifest of a release build.",
      "What the server does with what it receives: its own privacy policy states that, and this repository cannot check it.",
      "That a store's label definitions still fit these answers: Apple and Google change them, so re-read them when entering."
    ].freeze
  end
end
