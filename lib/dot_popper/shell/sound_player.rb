# frozen_string_literal: true

module DotPopper
  module Shell
    # Plays the game's sounds, which the synthesizer makes when the game
    # starts, each in mono so a pop or a mistake can be panned to where
    # it happened. Each sound has a few voices, so quick taps overlap rather
    # than cut each other off. With no audio device, or muted, it plays
    # nothing and the game goes on. Muting is remembered in +store+.
    class SoundPlayer
      VOICES = 4

      def initialize(patches, store:, volume: 1.0)
        @store = store
        @volume = volume
        @muted = store.read.to_s.strip == "muted"
        @voices = @base = build(patches)
        @next = Hash.new(0)
      end

      def muted? = @muted

      def toggle_mute
        @muted = !@muted
        @store.write(@muted ? "muted" : "on")
        @voices.each_value { |voices| voices.each(&:stop) } if @muted
        @muted
      rescue StandardError
        @muted
      end

      # Plays +name+ at +pitch+, panned by +pan+ from -1 (left) to 1
      # (right).
      def play(name, pitch: 1.0, pan: 0.0)
        return if @muted

        voices = @voices[name] or return
        voice = voices[@next[name] % voices.size]
        @next[name] += 1
        voice.stop
        voice.pitch = pitch
        voice.position = Presentation::Stereo.position(pan)
        voice.play
      rescue StandardError => e
        warn "Dot Popper: could not play #{name}: #{e.message}"
      end

      # Plays +theme+'s own sounds in place of the ordinary ones, or the
      # ordinary ones again. Made once per theme, the first time it is used.
      def use(theme)
        @theme_voices ||= {}
        built = (@theme_voices[theme.key] ||= build(theme.sounds))
        @voices = @base.merge(built)
        @next = Hash.new(0)
      end

      private

      def build(patches)
        patches.to_h do |name, patch|
          source = ::Lota::Audio::Source.new(sound_data(Presentation::Synth.render(patch)), :static)
          source.volume = @volume
          [name, ([source] + Array.new(VOICES - 1) { source.clone }).each { place(it) }]
        end
      rescue StandardError => e
        warn "Dot Popper: playing without sound (#{e.message})"
        {}
      end

      # Every sound is mono, so OpenAL can place it: each voice is placed
      # relative to the listener, which pans it by its angle (Stereo).
      def place(voice)
        voice.relative = true
        voice.position = Presentation::Stereo.position(Presentation::Stereo::CENTER)
      end

      def sound_data(samples)
        sound = ::Lota::Sound::SoundData.new(samples.size, Presentation::Synth::RATE, 16, 1)
        samples.each_with_index { |value, i| sound.sample = [i, value] }
        sound
      end
    end

    # Its old name, until no caller says it.
    Speaker = SoundPlayer
  end
end
