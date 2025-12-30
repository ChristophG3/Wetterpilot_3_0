# Wetterpilot 2.0 (SwiftUI, MVVM)

A minimal, working skeleton for the *Wetterpilot* app per your v2 spec.

## How to use
1. Open Xcode → File → New → **Project…** → iOS **App**. Product Name: *Wetterpilot*; Interface: *SwiftUI*; Language: *Swift*.
2. Quit Xcode. In Finder, replace the auto‑generated project's `Sources` with the contents of this repo, or simply drag these files into the Xcode project (keep folder references).
3. In the project settings:
   - **Localizations**: add German (de) and English (en).
   - **App Icons & Launch Images** → set **Launch Screen** to `LaunchScreen.storyboard`.
4. Add **Assets.xcassets** from `Resources/Assets.xcassets`. Replace `AppLogo` with your real vector PDF later.
5. Build & run.

> This code includes: MVVM layers, Open‑Meteo Geocoding + Forecast providers, 24h TTL disk/memory caches, scoring with 0–3 sliders, Welcome + Launch screens, PDF export for the summary, and date-keyed navigation to detail.
