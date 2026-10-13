import SwiftUI

@main
struct WeatherBarApp: App {
    @StateObject private var viewModel = WeatherViewModel()

    var body: some Scene {
        MenuBarExtra {
            WeatherPopOverView(viewModel: viewModel)
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
