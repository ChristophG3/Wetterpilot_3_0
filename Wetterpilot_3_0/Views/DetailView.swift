import SwiftUI

struct DetailView: View {
    @EnvironmentObject var vm: RouteVM
    let key: String // yyyy-MM-dd

    var body: some View {
        List {
            if let rows = vm.detailsByDate[key] {          // <— vm, nicht $vm
                ForEach(rows) { r in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.placeName).font(.headline)
                            Text(DF.display(isoKey: r.dateISO)).font(.caption).monospacedDigit()
                        }
                        Spacer()
                        Text(r.emoji).font(.title2)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(r.tRange)
                            Text("☔️ \(r.rain)  ☀️ \(r.sun)  🌬️ \(r.wind)")
                                .font(.caption)
                        }
                    }
                    .forecastCard()
                    .listRowNavy()
                }
            } else {
                Text("Keine Details verfügbar").listRowNavy()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(DF.display(isoKey: key)))
        .appBackground()
    }
}

