import SwiftUI
import SpriteKit

enum MenuColor {
    static let background = Color(red: 0.055, green: 0.094, blue: 0.063)
    static let panel = Color(red: 0.08, green: 0.13, blue: 0.09)
    static let line = Color(red: 0.17, green: 0.25, blue: 0.18)
    static let text = Color(red: 0.93, green: 0.95, blue: 0.89)
    static let muted = Color(red: 0.64, green: 0.71, blue: 0.61)
    static let hazard = Color(red: 0.953, green: 0.776, blue: 0.29)
    static let hazardInk = Color(red: 0.14, green: 0.11, blue: 0.02)
    static let grass = Color(red: 0.23, green: 0.39, blue: 0.2)
    static let rock = Color(red: 0.48, green: 0.5, blue: 0.45)
    static let water = Color(red: 0.18, green: 0.43, blue: 0.56)
    static let gate = Color(red: 0.6, green: 0.22, blue: 0.15)
    static let pad = Color(red: 0.42, green: 0.44, blue: 0.41)
    static let ash = Color(red: 0.24, green: 0.23, blue: 0.21)
    static let lava = Color(red: 0.95, green: 0.45, blue: 0.12)
    static let roof = Color(red: 0.72, green: 0.69, blue: 0.62)
}

struct MenuView: View {
    /// Park, difficulty, and whether it's an endless run.
    let onPlay: (Level, Difficulty, Bool) -> Void

    @AppStorage("difficulty") private var difficultyRaw = Difficulty.medium.rawValue
    @State private var showSettings = false

    private var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .medium
    }

    var body: some View {
        ZStack {
            BackdropLayer()
            LinearGradient(
                colors: [.black.opacity(0.7), .black.opacity(0.25), .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    difficultyPicker
                    parks
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 8) {
                    HazardStripes()
                        .frame(width: 30, height: 10)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    Text("TOWER DEFENSE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(MenuColor.hazard)
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(MenuColor.text)
                        .frame(width: 42, height: 42)
                        .background(MenuColor.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MenuColor.line))
                }
                .accessibilityLabel("Settings")
            }
            .padding(.bottom, 8)

            Text("DINO")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .foregroundStyle(MenuColor.text)
            Text("BREAKOUT")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(MenuColor.hazard)
                .padding(.top, -18)
            Text("The paddocks are open. Hold the line until the choppers arrive.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(MenuColor.muted)
                .padding(.top, 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DIFFICULTY")
            HStack(spacing: 8) {
                ForEach(Difficulty.allCases) { option in
                    let isOn = option == difficulty
                    Button {
                        difficultyRaw = option.rawValue
                    } label: {
                        Text(option.title)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(isOn ? MenuColor.hazardInk : MenuColor.text)
                            .background(isOn ? MenuColor.hazard : MenuColor.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn ? .clear : MenuColor.line))
                    }
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text(difficulty.blurb)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(MenuColor.muted)
        }
    }

    private var parks: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("CHOOSE A PARK")
                Spacer()
                Label("\(Progress.totalStars(difficulty: difficulty)) of \(Level.all.count * 3)", systemImage: "star.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(MenuColor.hazard)
                    .accessibilityLabel("\(Progress.totalStars(difficulty: difficulty)) stars on \(difficulty.title)")
            }
            ForEach(Level.all) { level in
                let unlocked = Progress.isUnlocked(level)
                VStack(spacing: 6) {
                    Button {
                        onPlay(level, difficulty, false)
                    } label: {
                        ParkCard(level: level, best: Progress.best(level: level, difficulty: difficulty), locked: !unlocked)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    if unlocked && Progress.hasBeaten(level) {
                        Button {
                            onPlay(level, difficulty, true)
                        } label: {
                            EndlessRow(best: Progress.endlessBest(level: level, difficulty: difficulty))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("More parks are under construction")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(MenuColor.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(MenuColor.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(MenuColor.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(MenuColor.muted)
    }
}

/// Endless mode for a park you've beaten, with your record.
private struct EndlessRow: View {
    let best: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "infinity")
                .font(.system(size: 16, weight: .heavy))
            Text("Endless")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
            Spacer()
            Text(best > 0 ? "Record: wave \(best)" : "No record yet")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(MenuColor.hazardInk)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MenuColor.hazard, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts an endless run")
    }
}

/// One park on the menu: a little map, its name, and your best wave.
private struct ParkCard: View {
    let level: Level
    let best: Int
    let locked: Bool

    var body: some View {
        HStack(spacing: 14) {
            ParkMap(level: level)
                .frame(width: 52, height: 82)
                .opacity(locked ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(level.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(locked ? MenuColor.muted : MenuColor.text)
                Text(level.blurb)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MenuColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if locked, let previous = level.previous {
                    Text("Reach wave \(Progress.unlockWave) in \(previous.name) to unlock")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(MenuColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                } else {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: i < Progress.stars(forBest: best) ? "star.fill" : "star")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(i < Progress.stars(forBest: best) ? MenuColor.hazard : MenuColor.muted)
                            }
                        }
                        Text(best > 0 ? "Best: wave \(best)" : "Not played yet")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(best > 0 ? MenuColor.hazard : MenuColor.muted)
                    }
                    .padding(.top, 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Progress.stars(forBest: best)) of 3 stars, best wave \(best)")
                }
            }
            Spacer(minLength: 4)
            Image(systemName: locked ? "lock.fill" : "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(locked ? MenuColor.muted : MenuColor.hazardInk)
                .frame(width: 40, height: 40)
                .background(locked ? MenuColor.panel : MenuColor.hazard, in: Circle())
                .overlay(Circle().stroke(locked ? MenuColor.line : .clear))
        }
        .padding(14)
        .background(MenuColor.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(MenuColor.line))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint(locked ? "Locked" : "Starts this park")
    }
}

/// Tiny top down map of a park: grass, boulders, river, gate, and helipad.
private struct ParkMap: View {
    let level: Level

    var body: some View {
        Canvas { context, size in
            let c = min(size.width / CGFloat(Level.cols), size.height / CGFloat(Level.rows))
            func rect(_ cell: Cell) -> CGRect {
                CGRect(x: CGFloat(cell.col) * c, y: CGFloat(Level.rows - 1 - cell.row) * c, width: c, height: c)
            }
            context.fill(Path(CGRect(x: 0, y: 0, width: c * CGFloat(Level.cols), height: c * CGFloat(Level.rows))), with: .color(level.ash ? MenuColor.ash : MenuColor.grass))
            for cell in level.lava {
                context.fill(Path(rect(cell)), with: .color(MenuColor.lava))
            }
            for cell in level.buildings {
                context.fill(Path(rect(cell)), with: .color(MenuColor.roof))
            }
            for cell in level.water {
                context.fill(Path(rect(cell)), with: .color(MenuColor.water))
            }
            for cell in level.bridges {
                context.fill(Path(rect(cell)), with: .color(Color(red: 0.6, green: 0.45, blue: 0.27)))
            }
            for cell in level.rocks {
                context.fill(Path(ellipseIn: rect(cell).insetBy(dx: c * 0.1, dy: c * 0.1)), with: .color(MenuColor.rock))
            }
            context.fill(Path(rect(level.spawn)), with: .color(MenuColor.gate))
            context.fill(Path(rect(level.exit)), with: .color(MenuColor.pad))
            context.stroke(Path(ellipseIn: rect(level.exit).insetBy(dx: c * 0.2, dy: c * 0.2)), with: .color(MenuColor.hazard), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.5), lineWidth: 1.5))
    }
}

/// The park with dinos wandering through it, filling the whole screen.
private struct BackdropLayer: View {
    @State private var scene: MenuBackdrop?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                MenuColor.background
                if let scene {
                    SpriteView(scene: scene)
                }
            }
            .onAppear {
                guard scene == nil, geo.size.width > 0 else { return }
                let backdrop = MenuBackdrop(size: geo.size)
                backdrop.scaleMode = .aspectFill
                scene = backdrop
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct HazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MenuColor.hazard))
            var x = -size.height
            while x < size.width {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height * 0.5, y: size.height))
                stripe.addLine(to: CGPoint(x: x + size.height * 1.5, y: 0))
                stripe.addLine(to: CGPoint(x: x + size.height, y: 0))
                stripe.closeSubpath()
                context.fill(stripe, with: .color(MenuColor.hazardInk))
                x += size.height
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage(SoundBank.musicKey) private var music = 0.5
    @AppStorage(SoundBank.effectsKey) private var effects = 0.8
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    volumeRow("Music", icon: "music.note", value: $music)
                    volumeRow("Sound effects", icon: "speaker.wave.2.fill", value: $effects)
                    Button {
                        SoundBank.shared.play(.roar)
                    } label: {
                        Label("Play a test roar", systemImage: "waveform")
                    }
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Slide all the way left to turn one off. The game also follows your phone's silent switch.")
                }

                Section("Difficulty") {
                    Text("Pick Easy, Medium, or Hard on the main screen. Your best wave is saved separately for each park and difficulty.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: music) { _, newValue in
                SoundBank.shared.musicVolume = Float(newValue)
            }
            .onChange(of: effects) { _, newValue in
                SoundBank.shared.effectsVolume = Float(newValue)
            }
        }
        .preferredColorScheme(.dark)
        .tint(MenuColor.hazard)
    }

    private func volumeRow(_ title: String, icon: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(value.wrappedValue == 0 ? "Off" : "\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1)
                .accessibilityLabel("\(title) volume")
        }
        .padding(.vertical, 4)
    }
}
