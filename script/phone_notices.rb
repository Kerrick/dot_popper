#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes the NOTICES.txt of Dot Popper's Android or iOS app, in the format
# of the one <tt>lota fuse</tt> writes into a desktop app (Lota::Notices).
# Lota's phone guide says it has no command yet that writes a phone app's
# notices, so the Android and Kits workflows call this, with the clone of
# Lota they build the engine from:
#
#   ruby script/phone_notices.rb android LOTA_CLONE OUT
#   ruby script/phone_notices.rb ios LOTA_CLONE OUT
#
# It reads the clone's record of who wrote what (ext/lota/licenses.rb,
# through Licensing), picks the works a phone build links (the ones every
# platform's build compiles in, and the ones recorded for that phone), and
# hands Lota::Notices their components and the clone's license texts. So
# the facts are Lota's own, at the version the workflow builds, and this
# file only chooses which of them the phone app holds. Android carries
# OpenAL Soft (LGPL) as libopenal.so, with its license and source in the
# app's licenses/ folder (the workflows put them there); iOS plays through
# Apple's OpenAL, which needs no notice.
module PhoneNotices
  PLATFORMS = {
    "android" => {
      suffix: "Android", platform: "android",
      bundle: "lib/{arm64-v8a,x86_64}/libfledgeext.so",
      libraries: { "libopenal.so" => "lib/{arm64-v8a,x86_64}/libopenal.so",
                   "libSDL3.so" => "lib/{arm64-v8a,x86_64}/libSDL3.so" },
      source: "licenses",
      # The vulkan sources are built into every non-Apple engine.
      leave_out: []
    },
    "ios" => {
      suffix: "iOS", platform: "ios",
      bundle: "the app's executable", libraries: {}, source: nil,
      leave_out: ["Vulkan-Headers", "volk", "Vulkan Memory Allocator"]
    }
  }.freeze

  # Works recorded for a platform carry its name in parentheses.
  PLATFORM_NAME = /\s\((?:Windows|iOS|Android)\)\z/

  module_function

  def text(platform, lota)
    setup = PLATFORMS.fetch(platform)
    require File.join(lota, "tasks", "licensing")
    require File.join(lota, "lib", "lota", "notices")
    licensing = Licensing.load(File.join(lota, "ext", "lota", "licenses.rb"))
    works = licensing.works.select { picked?(it, setup) }
    manifest = licensing.notices(bundle: setup.fetch(:bundle), works:, frameworks: setup.fetch(:libraries))
    components = manifest.fetch("components").map { component(it, licensing, setup) }
    notices(setup, lota).new(components:, texts: texts(lota), platform: setup.fetch(:platform),
                              gem_folder: ".").text
  end

  def picked?(work, setup)
    return false if work.pending || setup.fetch(:leave_out).include?(work.name)

    !work.name.match?(PLATFORM_NAME) || work.name.end_with?("(#{setup.fetch(:suffix)})")
  end

  # A component of the manifest, as Lota::Notices reads it. Android's
  # static libraries are built from the very releases the Windows gem
  # carries (Lota's tasks/android_build.rb), whose records give the names,
  # versions, and credit the Android ones leave out.
  def component(entry, licensing, setup)
    entry = entry.merge(from_windows(entry, licensing)) if setup.fetch(:suffix) == "Android"
    entry = entry.merge("source" => entry["source"].merge("file" => File.join(setup.fetch(:source), File.basename(entry["source"]["file"])))) if entry["source"]
    Lota::Notices::Component.from(entry)
  end

# Android names its shared libraries by file; the Linux gem records the
# same releases with their names and versions.
LINUX_TWINS = { "libopenal.so" => "libopenal.so.1", "libSDL3.so" => "libSDL3.so.0" }.freeze

def from_windows(entry, licensing)
  twin = if (linux = LINUX_TWINS[entry["name"]])
    licensing.framework_for(linux)
  else
    licensing.works.find { it.name == entry["name"].sub(/\s\(Android\)\z/, " (Windows)") && it.name != entry["name"] }
  end
  return {} unless twin

  { "name" => twin.notice_name, "version" => twin.notice_version, "credit" => twin.credit }
end

  # Lota::Notices, with the sentences a phone's app needs in place of the
  # ones that say a fuse wrote it, and with paths as they are in the app.
  def notices(setup, lota)
    Class.new(Lota::Notices) do
      define_method(:introduction) do
        "Notices for Lota #{Lota::VERSION} and the libraries Dot Popper's #{setup.fetch(:suffix)} app ships\n\n" \
          "Dot Popper's #{setup.fetch(:suffix)} workflow wrote this file from Lota's record of the libraries its " \
          "engine links on #{setup.fetch(:suffix)}, with the version of each where it is known, its licenses, and " \
          "its notices of copyright, and it ends with the text of every license it names. Each path is relative " \
          "to the folder that holds this file. The notices folder beside this file names Ruby and the rest of the " \
          "runtime the app runs on.\n"
      end
      define_method(:path) { |relative| relative.delete_prefix("./") == "." ? "the lota gem in the app's Ruby files" : relative.delete_prefix("./") }
      private :introduction, :path
    end
  end

  def texts(lota)
    from = Dir.glob(File.join(lota, "LICENSES", "*.txt")).to_h { [File.basename(it, ".txt"), it] }
    from.merge!(Dir.glob(File.join(lota, "ext", "lota", "licenses", "LICENSE-*.txt")).to_h do
      [File.basename(it, ".txt").delete_prefix("LICENSE-"), it]
    end)
    from.transform_values { File.read(it, encoding: Encoding::UTF_8) }
  end
end

if $PROGRAM_NAME == __FILE__
  platform, lota, out = ARGV
  abort "usage: phone_notices.rb android|ios LOTA_CLONE OUT" unless out && PhoneNotices::PLATFORMS.key?(platform)
  File.write(out, PhoneNotices.text(platform, File.expand_path(lota)))
end
