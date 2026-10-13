import Foundation
import SwiftUI

public struct WeatherIconMapper {
    /// Maps a condition text string (such as from NWS API or general forecast) to a corresponding SF Symbol name.
    public static func symbol(for condition: String, isDaytime: Bool = true) -> String {
        let lower = condition.lowercased()

        if lower.contains("thunder") || lower.contains("lightning") || lower.contains("t-storm") {
            return "cloud.bolt.rain.fill"
        }
        if lower.contains("tornado") || lower.contains("funnel") {
            return "tornado"
        }
        if lower.contains("snow") || lower.contains("blizzard") || lower.contains("flurries") {
            return isDaytime ? "cloud.snow.fill" : "cloud.snow"
        }
        if lower.contains("sleet") || lower.contains("freezing rain") || lower.contains("hail") || lower.contains("ice pellets") {
            return "cloud.sleet.fill"
        }
        if lower.contains("heavy rain") || lower.contains("downpour") || lower.contains("torrential") {
            return "cloud.heavyrain.fill"
        }
        if lower.contains("rain") || lower.contains("shower") || lower.contains("drizzle") {
            return isDaytime ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        }
        if lower.contains("fog") || lower.contains("mist") || lower.contains("haze") || lower.contains("smoke") {
            return "cloud.fog.fill"
        }
        if lower.contains("wind") || lower.contains("breezy") || lower.contains("blustery") {
            return "wind"
        }
        if lower.contains("partly cloudy") || lower.contains("partly sunny") || lower.contains("scattered") {
            return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
        }
        if lower.contains("mostly cloudy") || lower.contains("overcast") || lower.contains("cloudy") {
            return "cloud.fill"
        }
        if lower.contains("sunny") || lower.contains("clear") || lower.contains("fair") {
            return isDaytime ? "sun.max.fill" : "moon.stars.fill"
        }

        return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
    }

    /// Maps WMO Weather Interpretation Codes (0-99) commonly used by Open-Meteo to SF Symbols and condition descriptions.
    public static func fromWMOCode(_ code: Int, isDaytime: Bool = true) -> (description: String, symbol: String) {
        switch code {
        case 0:
            return (isDaytime ? "Clear Sky" : "Clear Sky", isDaytime ? "sun.max.fill" : "moon.stars.fill")
        case 1:
            return ("Mainly Clear", isDaytime ? "sun.max.fill" : "moon.stars.fill")
        case 2:
            return ("Partly Cloudy", isDaytime ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return ("Overcast", "cloud.fill")
        case 45, 48:
            return ("Fog", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 56, 57:
            return ("Freezing Drizzle", "cloud.sleet.fill")
        case 61, 63:
            return ("Rain", "cloud.rain.fill")
        case 65:
            return ("Heavy Rain", "cloud.heavyrain.fill")
        case 66, 67:
            return ("Freezing Rain", "cloud.sleet.fill")
        case 71, 73:
            return ("Snow Fall", "cloud.snow.fill")
        case 75:
            return ("Heavy Snow", "snowflake")
        case 77:
            return ("Snow Grains", "snowflake")
        case 80, 81:
            return ("Rain Showers", isDaytime ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill")
        case 82:
            return ("Violent Rain Showers", "cloud.heavyrain.fill")
        case 85, 86:
            return ("Snow Showers", "cloud.snow.fill")
        case 95:
            return ("Thunderstorm", "cloud.bolt.fill")
        case 96, 99:
            return ("Thunderstorm with Hail", "cloud.bolt.rain.fill")
        default:
            return ("Unknown", isDaytime ? "cloud.sun.fill" : "cloud.moon.fill")
        }
    }

    /// Icon tint color for nice SwiftUI presentation
    public static func iconColor(for symbol: String) -> Color {
        if symbol.contains("sun.max") {
            return .yellow
        } else if symbol.contains("cloud.sun") {
            return .orange
        } else if symbol.contains("bolt") {
            return .yellow
        } else if symbol.contains("rain") || symbol.contains("drizzle") {
            return .blue
        } else if symbol.contains("snow") || symbol.contains("snowflake") {
            return .cyan
        } else if symbol.contains("moon") {
            return .indigo
        } else if symbol.contains("fog") || symbol.contains("wind") {
            return .gray
        } else {
            return .cyan
        }
    }
}
