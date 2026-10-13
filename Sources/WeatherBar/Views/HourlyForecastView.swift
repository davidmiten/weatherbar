import SwiftUI

public struct HourlyForecastView: View {
    let items: [HourlyForecastItem]
    let unit: TemperatureUnit

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha" // e.g. "3PM"
        return f
    }()

    public init(items: [HourlyForecastItem], unit: TemperatureUnit) {
        self.items = items
        self.unit = unit
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("HOURLY FORECAST")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            VStack(spacing: 5) {
                                Text(timeFormatter.string(from: item.time).lowercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)

                                Image(systemName: item.iconSystemName)
                                    .font(.system(size: 18))
                                    .foregroundStyle(WeatherIconMapper.iconColor(for: item.iconSystemName))
                                    .frame(height: 24)

                                if let precip = item.precipitationChance, precip > 0 {
                                    Text("\(precip)%")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.cyan)
                                } else {
                                    Text(" ")
                                        .font(.system(size: 10))
                                }

                                Text(unit.formatShort(degreesFahrenheit: item.temperatureF))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .frame(width: 50)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}
