import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject var viewModel: WeatherViewModel

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 4) {
            switch viewModel.menuBarDisplayMode {
            case .iconAndTemp:
                Image(systemName: viewModel.menuBarIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(viewModel.menuBarTemperatureText)
                    .font(.system(.body, design: .rounded))
            case .iconOnly:
                Image(systemName: viewModel.menuBarIcon)
                    .symbolRenderingMode(.hierarchical)
            case .tempOnly:
                Text(viewModel.menuBarTemperatureText)
                    .font(.system(.body, design: .rounded))
            }
        }
    }
}
