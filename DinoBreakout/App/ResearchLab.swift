import SwiftUI

/// Spend amber on permanent upgrades. Every wave you clear earns some.
struct ResearchLab: View {
    @Environment(\.dismiss) private var dismiss
    /// Bumped after each purchase so the list redraws.
    @State private var purchases = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ResearchProject.allCases) { project in
                        row(project)
                    }
                } header: {
                    Label("\(Research.amber) amber", systemImage: "drop.fill")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(MenuColor.hazard)
                        .id(purchases)
                } footer: {
                    Text("Every wave you clear earns amber: 0.75 on Easy, 1 on Medium, 1.5 on Hard, plus 15 for beating all 50 waves or finishing the daily challenge. Research works in park and endless games, but never in daily challenges.")
                }
            }
            .navigationTitle("Research Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(MenuColor.hazard)
    }

    private func row(_ project: ResearchProject) -> some View {
        let level = Research.level(project)
        let cost = project.nextCost
        let affordable = cost.map { Research.amber >= $0 } ?? false
        return HStack(spacing: 14) {
            Image(systemName: project.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(level > 0 ? MenuColor.hazardInk : MenuColor.muted)
                .frame(width: 42, height: 42)
                .background(level > 0 ? MenuColor.hazard : MenuColor.panel, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Text(project.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(0..<ResearchProject.maxLevel, id: \.self) { i in
                        Capsule()
                            .fill(i < level ? MenuColor.hazard : MenuColor.line)
                            .frame(width: 22, height: 6)
                    }
                }
                .padding(.top, 2)
            }
            Spacer()
            if let cost {
                Button {
                    if Research.buy(project) {
                        purchases += 1
                        Haptics.punch()
                    }
                } label: {
                    Text("\(cost)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(minWidth: 44)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .foregroundStyle(affordable ? MenuColor.hazardInk : MenuColor.muted)
                        .background(affordable ? MenuColor.hazard : MenuColor.panel, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!affordable)
                .accessibilityLabel("Research for \(cost) amber")
            } else {
                Text("MAX")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(MenuColor.hazard)
            }
        }
        .padding(.vertical, 2)
        .id("\(project.rawValue)-\(purchases)")
    }
}
