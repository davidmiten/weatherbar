import Foundation

public enum TemperatureUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    public var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit (°F)"
        case .celsius: return "Celsius (°C)"
        }
    }

    public func format(degreesFahrenheit: Double) -> String {
        switch self {
        case .fahrenheit:
            return "\(Int(round(degreesFahrenheit)))°F"
        case .celsius:
            let celsius = (degreesFahrenheit - 32) * 5 / 9
            return "\(Int(round(celsius)))°C"
        }
    }

    public func formatShort(degreesFahrenheit: Double) -> String {
        switch self {
        case .fahrenheit:
            return "\(Int(round(degreesFahrenheit)))°"
        case .celsius:
            let celsius = (degreesFahrenheit - 32) * 5 / 9
            return "\(Int(round(celsius)))°"
        }
    }
}

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case iconAndTemp = "iconAndTemp"
    case iconOnly = "iconOnly"
    case tempOnly = "tempOnly"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iconAndTemp: return "Icon and Temperature"
        case .iconOnly: return "Icon Only"
        case .tempOnly: return "Temperature Only"
        }
    }
}

public enum RefreshInterval: Int, CaseIterable, Identifiable, Codable, Sendable {
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case manual = 0

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .tenMinutes: return "Every 10 minutes"
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .manual: return "Manual only"
        }
    }
}
