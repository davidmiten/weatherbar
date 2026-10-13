import SwiftUI

public struct DailyForecastView: View {
    let items: [DailyForecastItem]
    let unit: TemperatureUnit

    public init(items: [DailyForecastItem], unit: TemperatureUnit) {
        self.items = items
        self.unit = unit
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("EXTENDED FORECAST")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                VStack(spacing: 6) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Text(item.dayName)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 85, alignment: .leading)
                                .lineLimit(1)

                            Image(systemName: item.iconSystemName)
                                .font(.system(size: 15))
                                .foregroundStyle(WeatherIconMapper.iconColor(for: item.iconSystemName))
                                .frame(width: 22)

                            if let precip = item.precipitationChance, precip > 0 {
                                Text("\(precip)%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.cyan)
                                    .frame(width: 32, alignment: .leading)
                            } else {
                                Spacer()
                                    .frame(width: 32)
                            }

                            Text(item.condition)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Temperature
                            HStack(spacing: 4) {
                                if let low = item.lowF {
                                    Text(unit.formatShort(degreesFahrenheit: low))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                if let high = item.highF {
                                    Text(unit.formatShort(degreesFahrenheit: high))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 3)

                        if item.id != items.last?.id {
                            Divider()
                                .opacity(0.3)
                        }
                    }
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
