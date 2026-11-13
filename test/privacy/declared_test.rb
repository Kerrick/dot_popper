# frozen_string_literal: true

require "test_helper"
require "bundler"
require "prism"
require "dot_popper/presentation"
require "dot_popper/shell/save_file"
require "dot_popper/privacy/document"

# Each declared list, compared exactly with the file it describes. When one
# of these fails, the game has changed: declare the change in
# lib/dot_popper/privacy, then run `bundle exec rake privacy`.
class PrivacyDeclaredTest < Minitest::Test
  Privacy = DotPopper::Privacy
  ROOT = File.expand_path("../..", __dir__)

  def read(path) = File.read(File.join(ROOT, path)).gsub(/<!--.*?-->/m, "")

  def test_the_gems_shipped_are_declared
    shipped = Bundler.definition.specs_for([:default]).map(&:name).uniq - ["bundler"]

    assert_equal Privacy::SHIPPED_GEMS.keys.sort, shipped.sort
  end

  def test_the_android_dependencies_are_declared
    block = File.read(File.join(ROOT, "android/host/build.gradle"))[/^dependencies \{\n(.*?)^\}/m, 1]
    lines = block.lines.map(&:strip).reject(&:empty?)
    found = lines.map { it[/\Aimplementation\s+(?:'([^']+)'|(files\('[^']+'\)))\z/] ? ($1 || $2) : flunk("can't read: #{it}") }

    assert_equal Privacy::ANDROID_DEPENDENCIES.keys.sort, found.sort
  end

  def test_the_android_permissions_are_declared
    found = read("android/host/src/main/AndroidManifest.xml").scan(/<uses-permission(?:-sdk-\d+)?\s+android:name="([^"]+)"/).flatten

    assert_equal Privacy::ANDROID_PERMISSIONS.keys.sort, found.sort
  end

  def test_the_ios_usage_strings_are_declared
    found = %w[ios/host/Host/Info.plist].flat_map { read(it).scan(/<key>(NS\w+UsageDescription)<\/key>/).flatten }

    assert_equal Privacy::IOS_USAGE_STRINGS.keys.sort, found.sort
  end

  def test_the_ios_privacy_manifest_matches
    manifest = read("ios/host/Host/PrivacyInfo.xcprivacy")
    types = manifest.scan(%r{<key>NSPrivacyCollectedDataType</key>\s*<string>(\w+)</string>\s*<key>NSPrivacyCollectedDataTypeLinked</key>\s*<(true|false)/>\s*<key>NSPrivacyCollectedDataTypeTracking</key>\s*<(true|false)/>\s*<key>NSPrivacyCollectedDataTypePurposes</key>\s*<array>\s*<string>(\w+)</string>\s*</array>})
    apis = manifest.scan(%r{<key>NSPrivacyAccessedAPIType</key>\s*<string>(\w+)</string>\s*<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>(.*?)</array>}m).to_h { |type, reasons| [type, reasons.scan(%r{<string>([^<]+)</string>}).flatten] }
    sent = Privacy::REQUESTS.values.flat_map(&:labels).uniq

    assert_equal Privacy::STORE_LABELS.keys.sort, sent.sort, "every label is used by some request"
    assert_equal Privacy.store_labels.values.map { [it[:apple], it[:apple_linked].to_s, "false", Privacy::APPLE_PURPOSE] }.sort, types.sort
    assert_match(%r{<key>NSPrivacyTracking</key>\s*<false/>}, manifest)
    assert_match(%r{<key>NSPrivacyTrackingDomains</key>\s*<array/>}, manifest)
    assert_equal Privacy::APPLE_APIS, apis
  end

  def test_a_save_file_must_be_declared
    assert_raises(ArgumentError) { DotPopper::Shell::SaveFile.new(name: "secrets.txt") }
    assert_equal "stats.txt", DotPopper::Shell::SaveFile.new(name: "stats.txt").name
  end

  def test_every_save_file_in_the_code_is_declared_and_every_declared_one_is_in_the_code
    literals = saved_names.select { it.is_a?(String) }
    fixed = Privacy::SAVE_FILES.reject(&:pattern).map(&:name)
    named_elsewhere = [DotPopper::StatsBackup::NOTE, File.read(File.join(ROOT, "lib/dot_popper/shell/store_answers.rb"))[/NAME = "([^"]+)"/, 1]]

    assert_equal fixed.sort, (literals + constants_named + named_elsewhere).uniq.sort
    assert_equal 3, saved_names.count(:dynamic), "a new SaveFile.new with a computed name: name it, or add it here and declare its pattern"
  end

  def test_dated_names_match_their_patterns
    backups = []
    folder = ->(name) { backups << name; DotPopper::ScoreRecord::Memory.new }
    keeper = DotPopper::StatsBackup.new(score_record: memory("1"), stats_book: memory("2"), achievements: memory("3"), folder:)
    keeper.clear
    made = backups.grep(/\d{8}/)

    refute_empty made
    made.each { DotPopper::Shell::SaveFile.new(name: it) }
    archived = []
    log = DotPopper::GamesLog.new(DotPopper::ScoreRecord::Memory.new("old,columns\n1,2\n"), archive: ->(name) { archived << name; DotPopper::ScoreRecord::Memory.new })
    log.send(:current)

    refute_empty archived
    archived.each { DotPopper::Shell::SaveFile.new(name: it) }
    shot = File.read(File.join(ROOT, "lib/dot_popper/shell/development_hooks.rb"))[/name = "(shot-[^"]+)"/, 1].sub('#{number}', "3")
    DotPopper::Shell::SaveFile.new(name: shot)
  end

  def test_only_save_file_writes_to_the_save_folder
    allowed = { "lib/dot_popper/shell/store_answers.rb" => "File.delete", "lib/dot_popper/shell/development_hooks.rb" => "capture_screenshot" }
    ban = /\bFile\.(?:write|binwrite|open|delete|rename)\b|\bIO\.(?:write|binwrite)\b|\bFileUtils\b|Filesystem\.(?:write|append|remove|mkdir|create_directory|new_file)\b|capture_screenshot/
    hits = Dir[File.join(ROOT, "lib/**/*.rb")].reject { it.end_with?("shell/save_file.rb") }.filter_map do |path|
      found = source_of(path).scan(ban)
      rel = path.delete_prefix("#{ROOT}/")
      left = found - [allowed[rel]]
      "#{rel}: #{left.join(", ")}" unless left.empty?
    end

    assert_empty hits
  end

  def test_the_sensor_is_only_read_by_the_accelerometer
    users = Dir[File.join(ROOT, "lib/**/*.rb")].select { source_of(it).include?("Lota::Sensor") }.map { File.basename(it) }

    assert_equal ["accelerometer.rb"], users
  end

  def test_the_urls_the_game_opens_stay_on_the_device
    openers = Dir[File.join(ROOT, "lib/**/*.rb")].select { source_of(it).include?("open_url") }.map { File.basename(it) }

    assert_equal ["url_opener.rb"], openers
    assert_equal %w[dotpopper-share dotpopper-store], [DotPopper::Presentation::SheetSharing::SCHEME, DotPopper::Store::SCHEME].sort
  end

  def test_the_deletion_words_are_the_screens
    words = DotPopper::Presentation::Style::WORDS
    deletion = Privacy::Document.new.to_h.fetch(:deletion)

    assert_equal %i[privacy_heading privacy_delete privacy_hold].map { words.button(it) }, deletion.values_at(:screen, :control, :prompt)
  end

  def test_every_file_is_labeled_for_players_or_set_aside_with_a_reason
    assert_raises(ArgumentError) { Privacy::KeptFile.new(name: "x.txt", holds: "x") }
    assert_raises(ArgumentError) { Privacy::KeptFile.new(name: "x.txt", holds: "x", label: "X", aside: Privacy::Aside.new(kind: :diagnostics, reason: "y")) }
    assert_raises(ArgumentError) { Privacy::Aside.new(kind: :because, reason: "y") }
    Privacy::SAVE_FILES.each { assert it.label || it.aside.reason, it.name }
  end

  def test_what_a_file_also_sends_is_really_sent
    sent = Privacy::SAVE_FILES.flat_map { it.sent.keys }
    requests = Privacy::REQUESTS.values

    assert_equal %i[key score secret token], sent.sort
    assert(requests.any?(&:token))
    %i[score key secret].each { |field| assert(requests.any? { it.body.key?(field) }, field) }
  end

  def test_stays_on_the_device_excepts_what_leaves_it
    stays = Privacy::Document.new.to_h.dig(:on_device, :stays_on_the_device)

    Privacy::SAVE_FILES.flat_map { it.sent.values }.each { assert_includes stays, it }
  end

  def test_each_item_is_plain_or_record_only
    assert_raises(ArgumentError) { Privacy::Item.new(note: "x") }
    assert_raises(ArgumentError) { Privacy::Item.new(note: "x", plain: "y", record_only: "z") }
  end

  def test_what_a_player_reads_is_short_and_plain
    jargon = /renderer|vulkan|lota|l[oö]ve\b|\bsdl\b|fledge|\bsdks?\b|\bapi\b|\btoken\b|manifest|\.txt|\.csv|\bhttps?\b/i

    Privacy::Document.new.player_words.each do |sentence|
      refute_match jargon, sentence
      sentence.split(/(?<=[.!?])\s+/).each { assert_operator it.split.size, :<=, 25, it }
    end
  end

  # What the server's public page shows of the document, in GLOSSARY.md's
  # words: a record, Stats, and the player's private code (the code and
  # the API alone say token), and a game is a game.
  def test_what_the_privacy_page_shows_uses_the_glossarys_words
    document = Privacy::Document.new.to_h
    files = document.dig(:on_device, :files)
    shown = [*document.dig(:on_device, :for_players), *files.filter_map { it[:label] }, *files.map { it[:holds] },
             *document.dig(:network, :requests).map { it[:when] }, *document[:deletion].values_at(:sentence, :shown)]

    shown.each { refute_match(/\btokens?\b|\bbest\b|\bstatistics\b/i, it) }
    assert_includes document.dig(:on_device, :for_players), "Your record"
    assert_includes document.dig(:on_device, :for_players), "Your Stats"
    assert_equal "/games", Privacy::REQUESTS.fetch(:game).path
  end

  # Only a license key, from a website purchase, concerns one; a store's
  # copy never sends it (STORE_LABELS' license_key).
  def test_nothing_else_sent_concerns_a_purchase
    words = Privacy::REQUESTS.values.reject { it.labels.include?(:license_key) }.flat_map { [it.path, *it.body.keys, *it.query.keys] }.join(" ")

    refute_match(/purchase|receipt|entitlement|\bpro\b/i, words)
  end

  def test_the_network_permission_says_what_this_build_reaches
    purpose = Privacy::ANDROID_PERMISSIONS.fetch("android.permission.INTERNET")

    Privacy::REQUESTS.each_value { |request| assert_equal Privacy.features_built.include?(request.feature), purpose.include?(request.feature), request.kind }
  end

  def test_the_document_is_current
    assert_equal Privacy::Document.current_json, File.read(Privacy::Document::PATH), Privacy::Document::STALE
  end

  private

  def memory(text) = Struct.new(:saved) { def clear = nil }.new(text)

  def source_of(path)
    source = File.read(path)
    Prism.parse_comments(source).reverse_each { |c| source[c.location.start_offset...c.location.end_offset] = "" }
    source
  end

  def saved_names
    @saved_names ||= shell_sources.flat_map { |path| names_in(Prism.parse_file(path).value) }
  end

  # Where save files are opened: the shell (Shell::SaveFile.new), and the
  # composition root, which asks the engine for each by name (#file).
  def shell_sources = Dir[File.join(ROOT, "lib/dot_popper/{shell,composition}/*.rb")]

  # Each name a save file is opened by, leaving out the engine's and the
  # root's own #file, which only pass a name on.
  def names_in(node)
    return [] if node.is_a?(Prism::DefNode) && node.name == :file

    found = save_file_call?(node) ? [name_of(node)] : []
    node.compact_child_nodes.each { found.concat(names_in(it)) }
    found
  end

  def save_file_call?(node)
    return false unless node.is_a?(Prism::CallNode)
    return node.receiver.is_a?(Prism::ConstantReadNode) && node.receiver.name == :SaveFile if node.name == :new

    node.name == :file && node.arguments && (node.receiver.nil? || node.receiver.is_a?(Prism::InstanceVariableReadNode))
  end

  def name_of(call)
    first = call.arguments.arguments.first
    value = call.name == :file ? first : first.elements.find { it.key.unescaped == "name" }.value
    case value
    when Prism::StringNode then value.unescaped
    when Prism::ConstantReadNode then value.name
    else :dynamic
    end
  end

  # The constants passed to SaveFile.new, read from where they are set.
  def constants_named
    saved_names.grep(Symbol).reject { it == :dynamic }.map do |name|
      shell_sources.filter_map { File.read(it)[/\b#{name}\s*=\s*"([^"]+)"/, 1] }.first || flunk("can't find the save-file constant #{name}")
    end
  end
end
