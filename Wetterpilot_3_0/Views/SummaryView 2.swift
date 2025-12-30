import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var vm: RouteVM
    @State private var selectedKey: String?
    @State private var showShare = false
    @State private var pdfURL: URL?

    var body: some View {
        List {
            if let best = vm.summary.max(by: { a, b in a.score < b.score }) {
                Section(header: Text("Empfehlung")) {
                    card(for: best)
                        .onTapGesture { selectedKey = best.key }
                        .listRowNavy()
                }
            }
            Section(header: Text(NSLocalizedString("start_settings", comment: ""))) {
                ForEach(vm.summary) { item in
                    card(for: item)
                        .onTapGesture { selectedKey = item.key }
                        .listRowNavy()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(NSLocalizedString("start_settings", comment: ""))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let url = vm.deps.pdf.exportSummary(items: vm.summary, routeTitle: "Route") {
                        pdfURL = url; showShare = true
                    }
                } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(vm.summary.isEmpty)
            }
        }
        .sheet(isPresented: $showShare) {
            if let u = pdfURL { ShareSheet(activityItems: [u]) }
        }
        .navigationDestination(
            isPresented: Binding(get: { selectedKey != nil }, set: { if !$0 { selectedKey = nil } }),
            destination: { DetailView(key: selectedKey ?? "") }
        )
        .appBackground()
    }

    private func card(for item: SummaryItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(DF.display(isoKey: item.key)).font(.headline).monospacedDigit()
                Text(String(format: "☔️ %d  ☀️ %.1fh  🌬️ %.0f  🌡️ %.1f°C",
                            item.rainyDays, item.sunHours, item.avgWind, item.avgTemp))
                    .font(.caption)
            }
            Spacer()
            Text("Score \(item.score)").font(.headline)
        }
        .forecastCard()
    }
}

