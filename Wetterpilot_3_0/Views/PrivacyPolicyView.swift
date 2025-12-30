import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(NSLocalizedString("privacy_title", comment: ""))
                    .font(.title.bold())

                Group {
                    Text(NSLocalizedString("privacy_intro", comment: ""))

                    Text(NSLocalizedString("privacy_collection_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("privacy_collection_text", comment: ""))

                    Text(NSLocalizedString("privacy_processing_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("privacy_processing_text", comment: ""))

                    Text(NSLocalizedString("privacy_retention_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("privacy_retention_text", comment: ""))

                    Text(NSLocalizedString("privacy_rights_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("privacy_rights_text", comment: ""))

                    Text(NSLocalizedString("privacy_contact_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("privacy_contact_text", comment: ""))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .navigationTitle(Text(NSLocalizedString("privacy_nav_title", comment: "")))
        .toolbarTitleDisplayMode(.inline)
        .appBackground()
    }
}
