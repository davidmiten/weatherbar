import SwiftUI

public struct CurrentWeatherHeroView: View {
    @ObservedObject var viewModel: WeatherViewModel

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        if let current = viewModel.weatherData?.current {
            VStack(spacing: 12) {
                // Top section: Icon + Big Temperature + Condition
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: current.iconSystemName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .foregroundStyle(WeatherIconMapper.iconColor(for: current.iconSystemName))
                        .shadow(color: WeatherIconMapper.iconColor(for: current.iconSystemName).opacity(0.3), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.formattedCurrentTemp)
                            .font(.system(size: 42, weight: .semibold, design: .rounded))

                        Text(current.condition)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // High / Low & Apparent Temp
                    VStack(alignment: .trailing, spacing: 4) {
                        if current.highF != nil || current.lowF != nil {
                            HStack(spacing: 6) {
                                if current.highF != nil {
                                    Text("H: \(viewModel.formattedHighTemp)")
                                        .font(.subheadline.weight(.medium))
                                }
                                if current.lowF != nil {
                                    Text("L: \(viewModel.formattedLowTemp)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let feelsLike = viewModel.formattedApparentTemp {
                            Text("Feels like \(feelsLike)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()
                    .opacity(0.6)

                // Bottom section: 4-metric badge grid
                HStack(spacing: 8) {
                    MetricBadgeView(
                        icon: "humidity.fill",
                        label: "Humidity",
                        value: current.humidityPercent != nil ? "\(current.humidityPercent!)%" : "--",
                        tint: .blue
                    )

                    MetricBadgeView(
                        icon: "wind",
                        label: "Wind",
                        value: current.windSpeed,
                        tint: .teal
                    )

                    MetricBadgeView(
                        icon: "drop.fill",
                        label: "Precipitation",
                        value: current.probabilityOfPrecipitation != nil ? "\(current.probabilityOfPrecipitation!)%" : "0%",
                        tint: .cyan
                    )

                    if let dewpoint = current.dewpointF {
                        MetricBadgeView(
                            icon: "thermometer.snowflake",
                            label: "Dew Point",
                            value: viewModel.temperatureUnit.formatShort(degreesFahrenheit: dewpoint),
                            tint: .indigo
                        )
                    } else if let direction = current.windDirection {
                        MetricBadgeView(
                            icon: "safari",
                            label: "Direction",
                            value: direction,
                            tint: .indigo
                        )
                    } else {
                        MetricBadgeView(
                            icon: "sun.horizon.fill",
                            label: "Time",
                            value: current.isDaytime ? "Day" : "Night",
                            tint: .orange
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct MetricBadgeView: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        )
    }
}
