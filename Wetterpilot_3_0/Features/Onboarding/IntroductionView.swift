import SwiftUI

enum IntroductionPresentationMode: Equatable {
    case automatic
    case manual
}

private struct IntroductionPage: Identifiable {
    let id: Int
    let titleKey: String
    let bodyKey: String
    let symbolName: String

    static let all = [
        IntroductionPage(
            id: 0,
            titleKey: "introduction.plan.title",
            bodyKey: "introduction.plan.body",
            symbolName: "map"
        ),
        IntroductionPage(
            id: 1,
            titleKey: "introduction.weather.title",
            bodyKey: "introduction.weather.body",
            symbolName: "calendar.day.timeline.left"
        ),
        IntroductionPage(
            id: 2,
            titleKey: "introduction.flexible.title",
            bodyKey: "introduction.flexible.body",
            symbolName: "calendar.badge.clock"
        ),
        IntroductionPage(
            id: 3,
            titleKey: "introduction.decide.title",
            bodyKey: "introduction.decide.body",
            symbolName: "arrow.left.arrow.right.circle"
        )
    ]
}

struct IntroductionView: View {
    let mode: IntroductionPresentationMode
    let onClose: () -> Void

    @State private var selectedPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let pages = IntroductionPage.all

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    introductionContent
                }
            } else {
                introductionContent
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .foregroundStyle(AppTheme.primaryText)
        .tint(AppTheme.accent)
    }

    private var introductionContent: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    IntroductionPageView(page: pages[selectedPage])
                        .id(selectedPage)
                } else {
                    TabView(selection: $selectedPage) {
                        ForEach(pages) { page in
                            IntroductionPageView(page: page)
                                .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }

            pageIndicator
                .padding(.vertical, 12)

            Button {
                advanceOrClose()
            } label: {
                Text(
                    String(
                        localized: selectedPage == pages.count - 1
                            ? "introduction.getStarted"
                            : "introduction.continue"
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .buttonStyle(GradientPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var topBar: some View {
        HStack {
            if selectedPage > 0 {
                Button {
                    changePage(to: selectedPage - 1)
                } label: {
                    Label(
                        String(localized: "introduction.back"),
                        systemImage: "chevron.left"
                    )
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: 44)
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                onClose()
            } label: {
                Text(
                    String(
                        localized: mode == .automatic
                            ? "introduction.skip"
                            : "introduction.done"
                    )
                )
                .frame(minHeight: 44)
            }
        }
        .font(.body.weight(.semibold))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages) { page in
                Image(systemName: page.id == selectedPage ? "circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(
                        page.id == selectedPage ? AppTheme.accent : AppTheme.secondaryText
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "introduction.page \(selectedPage + 1) \(pages.count)"
            )
        )
    }

    private func advanceOrClose() {
        if selectedPage == pages.count - 1 {
            onClose()
        } else {
            changePage(to: selectedPage + 1)
        }
    }

    private func changePage(to page: Int) {
        if reduceMotion {
            selectedPage = page
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPage = page
            }
        }
    }
}

private struct IntroductionPageView: View {
    let page: IntroductionPage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesCompactAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    @ViewBuilder
    var body: some View {
        if usesCompactAccessibilityLayout {
            pageContent
        } else {
            ScrollView {
                pageContent
            }
        }
    }

    private var pageContent: some View {
        VStack(spacing: usesCompactAccessibilityLayout ? 14 : 28) {
            Spacer(minLength: usesCompactAccessibilityLayout ? 8 : 28)

            Image(systemName: page.symbolName)
                .font(
                    .system(
                        size: usesCompactAccessibilityLayout ? 44 : 76,
                        weight: .regular
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
                .frame(
                    minWidth: usesCompactAccessibilityLayout ? 64 : 120,
                    minHeight: usesCompactAccessibilityLayout ? 64 : 120
                )
                .accessibilityHidden(true)

            VStack(spacing: usesCompactAccessibilityLayout ? 10 : 14) {
                Text(String(localized: String.LocalizationValue(page.titleKey)))
                    .font(
                        usesCompactAccessibilityLayout
                            ? .title2.bold()
                            : .largeTitle.bold()
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(localized: String.LocalizationValue(page.bodyKey)))
                    .font(usesCompactAccessibilityLayout ? .body : .title3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: usesCompactAccessibilityLayout ? 8 : 28)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, usesCompactAccessibilityLayout ? 20 : 28)
        .accessibilityElement(children: .contain)
    }
}
