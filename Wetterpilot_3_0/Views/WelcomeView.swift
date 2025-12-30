import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var vm: RouteVM
    @State private var dontShowAgain: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(NSLocalizedString("welcome_title", comment: ""))
                .font(.largeTitle).bold().foregroundStyle(AppColor.onNavy)
            Text(NSLocalizedString("welcome_subtitle", comment: ""))
                .foregroundStyle(AppColor.onNavy.opacity(0.9))

            VStack(alignment: .leading, spacing: 8) {
                Label(NSLocalizedString("welcome_bullet_1", comment: ""), systemImage: "calendar")
                Label(NSLocalizedString("welcome_bullet_2", comment: ""), systemImage: "map")
                Label(NSLocalizedString("welcome_bullet_3", comment: ""), systemImage: "doc.richtext")
            }
            .foregroundStyle(AppColor.onNavy)

            Toggle(NSLocalizedString("welcome_dontshow", comment: ""), isOn: $dontShowAgain)
                .tint(.white)
                .foregroundStyle(AppColor.onNavy)
                .padding(.top, 8)

            Button(NSLocalizedString("welcome_cta", comment: "")) {
                vm.setHasSeenWelcome()
            }
            .primaryButton() // <— zentraler Aufruf
            .padding(.top, 4)

            Spacer()
        }
        .padding()
        .background(AppColor.navyBase.ignoresSafeArea())
    }
}
