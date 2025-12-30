import Foundation
import PDFKit
import SwiftUI

final class PDFExporter {
    func exportSummary(items: [SummaryItem], routeTitle: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let margin: CGFloat = 24
            var y: CGFloat = margin
            
            // Title
            let title = "Wetterpilot – " + routeTitle
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20)
            ]
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36
            
            // Headers
            let headers = ["Start", "Score", "Regen", "ØTemp", "Sonne", "ØWind"]
            let widths: [CGFloat] = [100, 60, 60, 70, 60, 60]
            var x: CGFloat = margin
            for (i, h) in headers.enumerated() {
                (h as NSString).draw(
                    at: CGPoint(x: x, y: y),
                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12)]
                )
                x += widths[i]
            }
            y += 20
            
            // Rows
            for item in items {
                x = margin
                let row = [
                    item.key,
                    String(item.score),
                    String(item.rainyDays),
                    String(format: "%.1f°C", item.avgTemp),
                    String(format: "%.1fh", item.sunHours),
                    String(format: "%.0f", item.avgWind)
                ]
                for (i, val) in row.enumerated() {
                    (val as NSString).draw(
                        at: CGPoint(x: x, y: y),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
                    )
                    x += widths[i]
                }
                y += 18
                if y > pageRect.height - 48 { // simple page break
                    ctx.beginPage()
                    y = margin
                }
            }
        }
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wetterpilot_Summary.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
