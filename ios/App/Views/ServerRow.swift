import SwiftUI

struct ServerRow: View {
    @Environment(Loc.self) private var loc

    let server: ProxyConfig
    let isSelected: Bool
    let isActive: Bool
    /// Outer nil = never tested; inner nil = tested and unreachable.
    let latency: Int??
    let isTesting: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .lineLimit(1)
                    .foregroundStyle(server.xraySupported ? .primary : .secondary)
                HStack(spacing: 6) {
                    Text(server.proto.rawValue.uppercased())
                    if server.isBalancer {
                        Text("×\((server.alternates?.count ?? 0) + 1)")
                    }
                    if !server.xraySupported {
                        Text(loc("needs sing-box"))
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            latencyBadge

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var latencyBadge: some View {
        if isTesting {
            ProgressView().controlSize(.mini)
        } else if let outer = latency {
            if let ms = outer {
                Text("\(ms) ms")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text(loc("timeout"))
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<150: return .green
        case ..<350: return .orange
        default:     return .red
        }
    }
}
