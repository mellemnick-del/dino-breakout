import AVFoundation

enum Sound: CaseIterable {
    case turret, tranq, flare, flak, hit, dinoDown, roar, screech, alarm, place, upgrade, sell, escape, win, lose, zap

    /// How loud this one sits in the mix.
    var gain: Float {
        switch self {
        case .turret: 0.45
        case .tranq: 0.55
        case .flare: 0.7
        case .flak: 0.6
        case .hit: 0.35
        case .dinoDown: 0.6
        case .roar: 1
        case .screech: 0.5
        case .alarm: 0.5
        case .place, .upgrade, .sell: 0.6
        case .escape: 0.6
        case .win, .lose: 0.7
        case .zap: 0.25
        }
    }

    /// Shortest gap between two plays, so a gatling doesn't turn into static.
    var minGap: TimeInterval {
        switch self {
        case .turret: 0.06
        case .flak: 0.08
        case .hit: 0.05
        case .zap: 0.2
        case .screech: 0.8
        default: 0.02
        }
    }
}

/// Plays the game's sound effects and music. Everything is synthesized when
/// the app starts, so there are no audio files to ship or license.
final class SoundBank {
    static let shared = SoundBank()

    static let musicKey = "musicVolume"
    static let effectsKey = "effectsVolume"

    var musicVolume: Float = 0.5 {
        didSet { music.volume = musicVolume * 0.6 }
    }
    var effectsVolume: Float = 0.8

    private let engine = AVAudioEngine()
    private let music = AVAudioPlayerNode()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private let sampleRate: Double = 44100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?
    private var lastPlayed: [Sound: TimeInterval] = [:]
    private var started = false
    /// Sounds are synthesized and the engine is running.
    private var ready = false

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.musicKey) != nil {
            musicVolume = defaults.float(forKey: Self.musicKey)
        }
        if defaults.object(forKey: Self.effectsKey) != nil {
            effectsVolume = defaults.float(forKey: Self.effectsKey)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        // Touch the lazy format here on the main thread before the background work reads it
        _ = format
        // Activating the audio session and synthesizing every sound takes a moment,
        // so it happens off the main thread and the menu appears right away
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Ambient: mixes with the player's own music and respects the silent switch
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            var made: [Sound: AVAudioPCMBuffer] = [:]
            for sound in Sound.allCases {
                made[sound] = make(sound)
            }
            let loop = makeMusic()

            DispatchQueue.main.async {
                buffers = made
                musicBuffer = loop
                startEngine()
            }
        }
    }

    private func startEngine() {
        engine.attach(music)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        for _ in 0..<10 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            voices.append(voice)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }
        ready = true
        music.volume = musicVolume * 0.6
        if let musicBuffer {
            music.scheduleBuffer(musicBuffer, at: nil, options: .loops)
            music.play()
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard ready, engine.isRunning, effectsVolume > 0, let buffer = buffers[sound] else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayed[sound], now - last < sound.minGap { return }
        lastPlayed[sound] = now
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.volume = effectsVolume * sound.gain * volume
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.play()
    }

    // MARK: - Synthesis

    private func buffer(_ duration: Double, _ sample: (Double, Int) -> Float) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            data[i] = max(-1, min(1, sample(Double(i) / sampleRate, i)))
        }
        return buffer
    }

    private func noise() -> Float {
        Float.random(in: -1...1)
    }

    private func sine(_ freq: Double, _ t: Double) -> Float {
        Float(sin(2 * .pi * freq * t))
    }

    private func square(_ freq: Double, _ t: Double) -> Float {
        sin(2 * .pi * freq * t) >= 0 ? 1 : -1
    }

    private func decay(_ t: Double, _ rate: Double) -> Float {
        Float(exp(-t * rate))
    }

    private func make(_ sound: Sound) -> AVAudioPCMBuffer? {
        var low: Float = 0
        func lowpass(_ x: Float, _ a: Float) -> Float {
            low += a * (x - low)
            return low
        }
        switch sound {
        case .turret:
            return buffer(0.14) { t, _ in
                lowpass(self.noise(), 0.5) * self.decay(t, 38) * 0.8 + self.sine(90 - t * 200, t) * self.decay(t, 28) * 0.7
            }
        case .tranq:
            return buffer(0.2) { t, _ in
                let attack = Float(min(1, t / 0.01))
                return lowpass(self.noise(), 0.18) * attack * self.decay(t, 22) * 1.4 + self.sine(1400 - t * 3000, t) * self.decay(t, 60) * 0.15
            }
        case .flare:
            return buffer(0.7) { t, _ in
                let swell = Float(pow(sin(.pi * min(1, t / 0.7)), 0.6)) * self.decay(t, 2.5)
                let crackle: Float = Float.random(in: 0...1) > 0.995 ? self.noise() * 1.2 : 0
                return lowpass(self.noise(), Float(0.05 + 0.25 * min(1, t * 4))) * swell * 1.6 + crackle * self.decay(t, 4)
            }
        case .flak:
            return buffer(0.4) { t, _ in
                self.sine(75 - t * 60, t) * self.decay(t, 9) * 0.8 + lowpass(self.noise(), 0.25) * self.decay(t, 14) * 0.9
            }
        case .hit:
            return buffer(0.05) { t, _ in self.sine(1800, t) * self.decay(t, 120) * 0.5 }
        case .dinoDown:
            return buffer(0.35) { t, _ in
                self.sine(120 - t * 150, t) * self.decay(t, 11) * 0.8 + lowpass(self.noise(), 0.1) * self.decay(t, 18) * 0.5
            }
        case .roar:
            return buffer(1.6) { t, _ in
                let attack = Float(min(1, t / 0.18))
                let release = Float(min(1, (1.6 - t) / 0.5))
                let growl = Float(1 + 0.45 * sin(2 * .pi * 17 * t))
                let pitch = 62 + 10 * sin(2 * .pi * 1.3 * t) - t * 12
                let saw = Float(2 * ((pitch * t).truncatingRemainder(dividingBy: 1)) - 1)
                return (lowpass(saw * 0.6 + self.noise() * 0.5, 0.12) * 2.2) * growl * attack * release
            }
        case .screech:
            return buffer(0.55) { t, _ in
                let attack = Float(min(1, t / 0.03))
                let pitch = 2300 - t * 1700 + 120 * sin(2 * .pi * 28 * t)
                let tone = self.sine(pitch, t) * 0.6 + self.sine(pitch * 1.5, t) * 0.25
                return (tone + self.noise() * 0.15) * attack * self.decay(t, 5)
            }
        case .alarm:
            return buffer(0.9) { t, _ in
                let step = Int(t / 0.15)
                let tone = self.square(step % 2 == 0 ? 660 : 880, t)
                return tone * 0.22 * Float(min(1, (0.9 - t) / 0.1))
            }
        case .place:
            return buffer(0.14) { t, _ in
                self.sine(220, t) * self.decay(t, 30) * 0.7 + lowpass(self.noise(), 0.6) * self.decay(t, 90) * 0.4
            }
        case .upgrade:
            return buffer(0.4) { t, _ in
                let notes: [Double] = [523, 659, 784]
                let index = min(2, Int(t / 0.1))
                let local = t - Double(index) * 0.1
                return self.sine(notes[index], t) * self.decay(local, 10) * 0.5
            }
        case .sell:
            return buffer(0.35) { t, _ in
                (self.sine(1318, t) * 0.4 + self.sine(1760, t) * 0.3) * self.decay(t, 9) * Float(t < 0.06 ? 1 : 0.8)
            }
        case .escape:
            return buffer(0.45) { t, _ in
                self.square(140, t) * 0.25 * Float(min(1, (0.45 - t) / 0.15))
            }
        case .win:
            return buffer(1.1) { t, _ in
                let notes: [Double] = [523, 659, 784, 1046]
                let index = min(3, Int(t / 0.16))
                let local = t - Double(index) * 0.16
                return (self.sine(notes[index], t) + self.sine(notes[index] * 2, t) * 0.25) * self.decay(local, index == 3 ? 3 : 8) * 0.45
            }
        case .lose:
            return buffer(1.2) { t, _ in
                let notes: [Double] = [392, 330, 262]
                let index = min(2, Int(t / 0.3))
                let local = t - Double(index) * 0.3
                return (self.sine(notes[index], t) + self.square(notes[index] / 2, t) * 0.15) * self.decay(local, index == 2 ? 2.5 : 5) * 0.45
            }
        case .zap:
            return buffer(0.16) { t, _ in
                let burst: Float = Float.random(in: 0...1) > 0.7 ? 1 : 0.15
                let x = self.noise()
                let high = x - lowpass(x, 0.3)
                return high * burst * self.decay(t, 22) * 0.9
            }
        }
    }

    /// Eight seconds of jungle drums over a low drone, looped.
    private func makeMusic() -> AVAudioPCMBuffer? {
        let beat = 0.5
        let length = 8.0
        let kicks: [Double] = [0, 1, 2.5, 3, 4, 5, 6.5, 7, 7.5]
        let toms: [(at: Double, pitch: Double)] = [(0.75, 110), (1.75, 98), (2.75, 110), (3.5, 82), (4.75, 110), (5.75, 98), (6.75, 123), (7.25, 98)]
        let chirps: [(at: Double, pitch: Double)] = [(1.3, 2400), (4.4, 2900), (6.1, 2600)]
        var shaker: Float = 0
        return buffer(length) { t, _ in
            var out: Float = 0
            // Drone: two low notes breathing slowly
            let breathe = Float(0.6 + 0.4 * sin(2 * .pi * t / length))
            out += (self.sine(55, t) * 0.5 + self.sine(82.4, t) * 0.3) * 0.18 * breathe
            for k in kicks {
                let local = t - k * beat
                if local >= 0 && local < 0.35 {
                    out += self.sine(60 - local * 80, local) * self.decay(local, 9) * 0.55
                }
            }
            for tom in toms {
                let local = t - tom.at * beat
                if local >= 0 && local < 0.3 {
                    out += self.sine(tom.pitch, local) * self.decay(local, 13) * 0.35
                }
            }
            // Shaker on every eighth note
            let eighth = (t / (beat / 2)).truncatingRemainder(dividingBy: 1) * beat / 2
            let x = self.noise()
            shaker += 0.35 * (x - shaker)
            out += (x - shaker) * self.decay(eighth, 60) * 0.12
            for chirp in chirps {
                let local = t - chirp.at
                if local >= 0 && local < 0.12 {
                    out += self.sine(chirp.pitch + local * 6000, local) * Float(sin(.pi * local / 0.12)) * 0.06
                }
            }
            // Fade the loop edges so the seam doesn't click
            let edge = Float(min(1, min(t, length - t) / 0.02))
            return out * edge
        }
    }
}
