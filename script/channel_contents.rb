# frozen_string_literal: true

# What a built package holds that its channel does not need: another
# channel's way of selling Pro, the test build's fakes and test keys, and
# files no build loads. It reads an unpacked package (a folder), never
# this repository, and asks nothing of the internet.
#
#   ruby script/channel_contents.rb list CHANNEL FOLDER
#     prints each piece FOLDER holds that CHANNEL does not need: its whole
#     files, and the files that name it, with how often. Exits 0.
#   ruby script/channel_contents.rb check CHANNEL FOLDER
#     also fails (exit 1) if FOLDER holds a file that CHANNEL's build
#     leaves out (LEFT_OUT), so what was left out cannot come back.
#   ruby script/channel_contents.rb excludes [CHANNEL]
#     prints, one to a line, the paths CHANNEL's build leaves out, for
#     `lota fuse --exclude` (.github/actions/fuse). With no CHANNEL, the
#     channel of this working copy (Build::CHANNEL, as
#     script/set_build_channel.rb sets it).
#
# CHANNEL is one of Build::CHANNEL_NAMES, or "test" for a test build (a
# build with no channel: every playtest kit). A test build needs every
# fake and test key, and leaves nothing out (ADR-0009).
#
# Ruby's pieces are looked for only in the game's own folder
# (game/dot_popper, as `lota fuse` lays it out), so Ruby's and Lota's own
# files never match them; a native piece (a store's library or helper) is
# looked for in every file of the package. A piece that only some channels
# need is reported for every other channel, whether or not it could be
# left out today: PACKAGING.md says which can, and why the rest cannot.
require_relative "../lib/dot_popper/build"

module ChannelContents
  Build = DotPopper::Build
  TEST = "test"
  CHANNELS = [TEST, *Build::CHANNEL_NAMES].freeze

  # +needed_by+ the channels that use it; +files+ its own files, relative
  # to the game's folder; +marks+ the text that names it, wherever it is;
  # +everywhere+ whether to look in the whole package, not only the game;
  # +apart+ how far the game's code keeps it apart already: :files, so a
  # build for sale that doesn't need it leaves its files out (LEFT_OUT);
  # :all, so such a build holds none of its marks either; nil, not yet.
  Piece = Data.define(:name, :needed_by, :files, :marks, :everywhere, :apart) do
    def initialize(name:, needed_by:, marks:, files: [], everywhere: false, apart: nil) = super
  end

  PIECES = [
    Piece.new(name: "the fake store", needed_by: [TEST],
              files: %w[lib/dot_popper/presentation/fake_store.rb],
              marks: [/FakeStore/, /DOT_POPPER_FAKE_STORE_FAILS/, /fake_store\.txt/]),
    Piece.new(name: "the fake website checkout", needed_by: [TEST], marks: [/FakeCheckout/]),
    Piece.new(name: "the fake setdef server", needed_by: [TEST], marks: [/FakeSetdef/, /DOT_POPPER_FAKE_SETDEF/, /fake_setdef\.txt/]),
    Piece.new(name: "the test keys", needed_by: [TEST], apart: :files,
              files: %w[lib/dot_popper/test_build],
              marks: [/BEGIN PRIVATE KEY/, /\bTestKeys?\b/, /TEST_PINS/, /Receipt::TEST\b/]),
    Piece.new(name: "the test build's settings that grant Pro or skip the free-game limit", needed_by: [TEST],
              marks: [/DOT_POPPER_PRO\b/, /DOT_POPPER_FREE_GAMES/, /DOT_POPPER_TODAY/, /DOT_POPPER_THEME_UNLOCKS/]),
    Piece.new(name: "the website checkout", needed_by: [TEST, Build::WEBSITE],
              files: %w[lib/dot_popper/presentation/website_store.rb],
              marks: [/WebsiteStore/, /BrowserCheckout/, %r{dot-popper\.setdef\.com/buy}]),
    Piece.new(name: "license keys", needed_by: [TEST, Build::WEBSITE],
              files: %w[lib/dot_popper/continuity/license_key.rb lib/dot_popper/continuity/license.rb],
              marks: [/LicenseKey/, /license\.txt/, /license_checks/, /Paste license key/, /comes by email/]),
    Piece.new(name: "Google Play's receipts", needed_by: [TEST, Build::GOOGLE_PLAY],
              files: %w[lib/dot_popper/receipt/play.rb], marks: [/module Play\b/, /Receipt::Play\b/, /PLAY_KEYS/]),
    Piece.new(name: "Apple's receipts", needed_by: [Build::APP_STORE, Build::MAC_APP_STORE],
              files: %w[lib/dot_popper/receipt/apple.rb], marks: [/module Apple\b/, /APPLE_ROOT_G3/]),
    Piece.new(name: "the Microsoft Store's license", needed_by: [Build::MICROSOFT_STORE],
              files: %w[lib/dot_popper/receipt/microsoft.rb], marks: [/module Microsoft\b/, /windows_license/]),
    Piece.new(name: "the computer stores' helper", needed_by: [Build::MAC_APP_STORE, Build::MICROSOFT_STORE],
              files: %w[lib/dot_popper/shell/store_helper.rb], marks: [/StoreHelper/]),
    Piece.new(name: "Google Play Billing", needed_by: [Build::GOOGLE_PLAY], everywhere: true,
              marks: [/com\.android\.billingclient/, /ProStore/]),
    Piece.new(name: "StoreKit", needed_by: [Build::APP_STORE, Build::MAC_APP_STORE], everywhere: true,
              marks: [/StoreKit/]),
    Piece.new(name: "Windows.Services.Store", needed_by: [Build::MICROSOFT_STORE], everywhere: true,
              marks: [/Windows\.Services\.Store/]),
    # The privacy document's sources: the tests and doc/privacy.json read
    # them; the game loads only privacy/save_files.rb (Shell::SaveFile).
    Piece.new(name: "privacy declarations the game never loads", needed_by: [],
              files: %w[lib/dot_popper/privacy/declared.rb lib/dot_popper/privacy/document.rb lib/dot_popper/privacy/requests.rb],
              marks: [], apart: :all)
  ].freeze

  # A build for sale carries only what its channel needs: each separate
  # piece its channel doesn't need is left out of its package (the fuse
  # action passes these to `lota fuse --exclude`), and `check` fails if the
  # package holds any of its files or marks. A piece the game's loaders
  # still require is not separate yet: leaving it out would stop the app
  # starting. A test build (every playtest kit) keeps everything.
  LEFT_OUT = Build::CHANNEL_NAMES.to_h do |channel|
    [channel, PIECES.select { it.apart && !it.needed_by.include?(channel) }.freeze]
  end.freeze

  module_function

  def left_out_pieces(channel) = LEFT_OUT.fetch(channel, [])
  def left_out(channel) = left_out_pieces(channel).flat_map(&:files)

  def unneeded(channel) = PIECES.reject { it.needed_by.include?(channel) }

  # The game's folder in the unpacked package +folder+, or nil.
  def game_in(folder)
    games = Dir.glob(File.join(folder, "**", "game", "dot_popper", "lib", "dot_popper", "build.rb"))
    abort "#{folder} holds #{games.size} copies of the game; expected one" if games.size > 1
    games.first&.then { File.expand_path("../../..", it) }
  end

  # What +folder+ holds of each piece +channel+ does not need: [piece,
  # files present, { file => { mark => count } }], for the pieces it holds.
  def found(channel, folder)
    folder = File.expand_path(folder)
    game = game_in(folder)
    every = Dir.glob(File.join(folder, "**", "*"), File::FNM_DOTMATCH).select { File.file?(it) }
    ours = game ? every.select { it.start_with?("#{game}/") } : []
    # Each file by its path in the game, or else in the package.
    label = ->(path) { game && path.start_with?("#{game}/") ? path.delete_prefix("#{game}/") : path.delete_prefix("#{folder}/") }
    texts = {}
    unneeded(channel).filter_map do |piece|
      present = game ? piece.files.select { File.exist?(File.join(game, it)) } : []
      named = (piece.everywhere ? every : ours).each_with_object({}) do |path, hits|
        text = texts[path] ||= File.binread(path)
        counts = piece.marks.to_h { [shown(it), text.scan(it).size] }.reject { _2.zero? }
        hits[label.call(path)] = counts unless counts.empty?
      end
      [piece, present, named] unless present.empty? && named.empty?
    end
  end

  # A mark as text to read: the pattern without its escapes.
  def shown(mark) = mark.source.gsub("\\b", "").delete("\\")

  def report(channel, folder, out = $stdout)
    game = game_in(folder)
    out.puts "#{folder}, a #{channel == TEST ? "test build" : "#{channel} build"}; the game's folder: #{game || "none found"}"
    held = found(channel, folder)
    out.puts "It holds nothing its channel does not need." if held.empty?
    held.each do |piece, present, named|
      out.puts "", "#{piece.name} (needed by #{piece.needed_by.empty? ? "no build" : piece.needed_by.join(", ")})"
      present.each { out.puts "  file #{it}" }
      named.each { |path, counts| out.puts "  text #{path}: #{counts.map { |mark, n| "#{mark} x#{n}" }.join(", ")}" }
    end
    held
  end

  # What +channel+'s build leaves out that +folder+ holds anyway, each as a
  # line to print: a file, or a file that names a left-out piece.
  def returned(channel, folder)
    game_in(folder) or abort("#{folder} holds no game to check")
    pieces = left_out_pieces(channel)
    found(channel, folder).select { |piece, _, _| pieces.include?(piece) }.flat_map do |piece, present, named|
      named = {} unless piece.apart == :all
      present.map { "#{it} (#{piece.name})" } + named.map { |path, counts| "#{path}, which names #{piece.name} (#{counts.keys.join(", ")})" }
    end
  end

  def main(argv)
    command, *rest = argv
    case command
    when "excludes"
      channel = rest.first || Build::CHANNEL || TEST
      usage unless CHANNELS.include?(channel)
      puts left_out(channel)
    when "list", "check"
      channel, folder = rest
      usage unless CHANNELS.include?(channel) && folder && File.directory?(folder)
      # One spelling of the path, with forward slashes, which Dir.glob
      # needs on Windows (D:\a\_temp/unzipped finds nothing).
      folder = File.expand_path(folder)
      report(channel, folder)
      back = command == "check" ? returned(channel, folder) : []
      back.each { warn "FAIL #{folder} holds #{it}, which a #{channel} build leaves out" }
      exit(back.empty? ? 0 : 1)
    else usage
    end
  end

  def usage
    abort "usage: ruby script/channel_contents.rb list|check CHANNEL FOLDER, or excludes [CHANNEL] " \
          "(CHANNEL one of #{CHANNELS.join(", ")})"
  end
end

ChannelContents.main(ARGV) if $PROGRAM_NAME == __FILE__
