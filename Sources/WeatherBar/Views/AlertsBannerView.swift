import SwiftUI

public struct AlertsBannerView: View {
    let alerts: [WeatherAlert]
    @State private var isExpanded: Bool = false

    public init(alerts: [WeatherAlert]) {
        self.alerts = alerts
    }

    public var body: some View {
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(alerts[0].event)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)

                            if let headline = alerts[0].headline, !headline.isEmpty {
                                Text(headline)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        ForEach(alerts) { alert in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(alert.severity.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.orange.opacity(0.2)))
                                        .foregroundColor(.orange)

                                    Text(alert.event)
                                        .font(.system(size: 11, weight: .semibold))
                                }

                                Text(alert.description)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(6)

                                if let instruction = alert.instruction, !instruction.isEmpty {
                                    Text("Action: \(instruction)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.orange)
                                        .padding(.top, 2)
                                }
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
