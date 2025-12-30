import SwiftUI

@main
struct WetterpilotApp: App {
    @StateObject private var vm = RouteVM(deps: AppDependencies.live)
    
    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .environmentObject(vm)
        }
    }
}

struct RootRouterView: View {
    @EnvironmentObject var vm: RouteVM
    @State private var showWelcome: Bool = false
    
    var body: some View {
        Group {
            if vm.hasSeenWelcome == false {
                WelcomeView()
            } else {
                StartView()
            }
        }
        .onAppear { showWelcome = !vm.hasSeenWelcome }
    }
}
