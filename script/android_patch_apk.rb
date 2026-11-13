# frozen_string_literal: true

# Makes the Android app for this commit's game from an app built for
# another commit whose every other input was the same
# (script/android_check.sh): the game's files the app carries are only
# app/game/dot_popper/ and app/main.rb in the app's asset fledge.zip
# (script/android_game.sh lays them out), so those are replaced and
# everything else in both archives is kept as it was, byte for byte.
#
#   ruby script/android_patch_apk.rb BASE.apk PROJECT OUT.apk
#
# PROJECT is what script/android_game.sh laid out. OUT.apk is unsigned
# and not yet aligned: zipalign and apksigner come next, as Gradle's own
# packaging ends. The base app's signature (its APK Signing Block, and any
# v1 signature files) is left out, since it signed other bytes.
#
# Both archives are ZIP files with no ZIP64 records, as an APK under
# 4 GB with fewer than 65,535 entries is; anything else is refused.
require "zlib"

module AndroidPatch
  ASSET = "assets/fledge.zip"
  GAME = "app/game/dot_popper/"
  MAIN = "app/main.rb"
  SIGNATURE = %r{\AMETA-INF/([^/]+\.(SF|RSA|DSA|EC)|MANIFEST\.MF)\z}

  # One entry of a ZIP file: its name, its local header and data as they
  # are in the file (+raw+), and its central directory record (+central+),
  # whose offset is filled in when it is written.
  Entry = Struct.new(:name, :raw, :central)

  module_function

  # The entries of the ZIP file +bytes+, in the order of its central
  # directory.
  def entries(bytes)
    eocd = bytes.rindex("PK\x05\x06".b) or raise ArgumentError, "not a ZIP file"
    count, size, start = bytes.unpack("@#{eocd + 10}vVV")
    raise ArgumentError, "a ZIP64 file" if [count, size, start].include?(0xFFFF) || start == 0xFFFFFFFF

    position = start
    Array.new(count) do
      raise ArgumentError, "a broken central directory" unless bytes.byteslice(position, 4) == "PK\x01\x02".b

      compressed, name_length, extra_length, comment_length, offset =
        bytes.unpack("@#{position + 20}V@#{position + 28}vvv@#{position + 42}V")
      record = bytes.byteslice(position, 46 + name_length + extra_length + comment_length)
      name = record.byteslice(46, name_length)
      flags, local_name, local_extra = bytes.unpack("@#{offset + 6}v@#{offset + 26}vv")
      length = 30 + local_name + local_extra + compressed
      # A data descriptor follows the data when the sizes came after it.
      length += bytes.byteslice(offset + length, 4) == "PK\x07\x08".b ? 16 : 12 if flags.anybits?(8)
      raw = bytes.byteslice(offset, length)
      position += record.bytesize
      Entry.new(name.force_encoding(Encoding::UTF_8), raw, record)
    end
  end

  # A stored (uncompressed) entry named +name+ holding +data+, or a
  # folder's entry for a name that ends in "/", with Unix permissions
  # +mode+ and the DOS time of 1981-01-01, as Android's packaging writes.
  def stored(name, data = "", mode: name.end_with?("/") ? 0o40755 : 0o100644)
    name = name.b
    data = data.b
    crc = Zlib.crc32(data)
    time = 0
    date = (1 << 9) | (1 << 5) | 1
    local = ["PK\x03\x04".b, 10, 0x0800, 0, time, date, crc, data.bytesize, data.bytesize, name.bytesize, 0].pack("a4vvvvvVVVvv")
    central = ["PK\x01\x02".b, (3 << 8) | 20, 10, 0x0800, 0, time, date, crc, data.bytesize, data.bytesize, name.bytesize, 0, 0, 0, 0,
               mode << 16, 0].pack("a4vvvvvvVVVvvvvvVV")
    Entry.new(name.force_encoding(Encoding::UTF_8), local + name + data, central + name)
  end

  # A ZIP file of +entries+, each local header where its central record
  # says.
  def write(entries)
    out = String.new(encoding: Encoding::BINARY)
    directory = String.new(encoding: Encoding::BINARY)
    entries.each do |entry|
      record = entry.central.b
      record[42, 4] = [out.bytesize].pack("V")
      directory << record
      out << entry.raw.b
    end
    start = out.bytesize
    out << directory
    out << ["PK\x05\x06".b, 0, 0, entries.size, entries.size, directory.bytesize, start, 0].pack("a4vvvvVVv")
  end

  # The stored data of +entry+, which must be stored.
  def data(entry)
    method, size = entry.central.unpack("@10v@20V")
    raise ArgumentError, "#{entry.name} is compressed" unless method.zero?

    name_length, extra_length = entry.raw.unpack("@26vv")
    entry.raw.byteslice(30 + name_length + extra_length, size)
  end

  # The entries for what +project+ holds under game/dot_popper and its
  # main.rb, named as the app's asset names them.
  def game(project)
    root = File.join(project, "game", "dot_popper")
    names = Dir.glob("**/*", File::FNM_DOTMATCH, base: root).reject { File.basename(it).match?(/\A\.\.?\z/) }.sort
    [stored(GAME)] + names.map do |name|
      path = File.join(root, name)
      if File.directory?(path)
        stored("#{GAME}#{name}/")
      else
        stored("#{GAME}#{name}", File.binread(path), mode: File.executable?(path) ? 0o100755 : 0o100644)
      end
    end + [stored(MAIN, File.binread(File.join(project, "main.rb")))]
  end

  # The app +apk+ (bytes) with the game in +project+ in place of its own.
  def patch(apk, project)
    outer = entries(apk)
    asset = outer.find { it.name == ASSET } or raise ArgumentError, "the app has no #{ASSET}"
    inner = entries(data(asset)).reject { it.name.start_with?(GAME) || it.name == MAIN }
    raise ArgumentError, "the app's #{ASSET} holds no app/" unless inner.any? { it.name.start_with?("app/") }

    zip = write(inner + game(project))
    kept = outer.reject { it.name == ASSET || it.name.match?(SIGNATURE) }
    write(kept + [stored(ASSET, zip)])
  end
end

module AndroidPatch
  module_function

  # What the app +apk+ (bytes) holds, by name: each entry's CRC-32 and
  # size, and those of every entry of its fledge.zip, named under it;
  # its signature left out.
  def contents(apk)
    outer = entries(apk).reject { it.name.match?(SIGNATURE) }
    asset = outer.find { it.name == ASSET }
    listed = ->(list, under) { list.to_h { ["#{under}#{it.name}", it.central.unpack("@16VV@24V")] } }
    listed.(outer.reject { it == asset }, "").merge(listed.(entries(data(asset)), "#{ASSET}!"))
  end

  # The names whose contents differ between the apps +one+ and +other+.
  def differences(one, other)
    mine = contents(one)
    theirs = contents(other)
    (mine.keys | theirs.keys).reject { mine[it] == theirs[it] }.sort
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "--same" && ARGV.size == 3
    differences = AndroidPatch.differences(File.binread(ARGV[1]), File.binread(ARGV[2]))
    abort "The apps differ in:\n#{differences.first(40).join("\n")}" unless differences.empty?
    puts "The apps hold the same files."
  else
    base, project, out = ARGV
    unless base && project && out && ARGV.size == 3
      abort "usage: ruby script/android_patch_apk.rb BASE.apk PROJECT OUT.apk\n" \
            "       ruby script/android_patch_apk.rb --same ONE.apk OTHER.apk"
    end
    File.binwrite(out, AndroidPatch.patch(File.binread(base), project))
  end
end
