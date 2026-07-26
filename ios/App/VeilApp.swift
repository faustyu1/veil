import SwiftUI

@main
struct VeilApp: App {
    @State private var store = ServerStore()
    @State private var tunnel = TunnelController()
    @State private var pinger = PingTester()
    @State private var loc = Loc()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(tunnel)
                .environment(pinger)
                .environment(loc)
                .preferredColorScheme(colorScheme)
                .environment(\.layoutDirection, loc.isRTL ? .rightToLeft : .leftToRight)
                .task { await bootstrap() }
        }
    }

    private func bootstrap() async {
        loc.language = store.settings.language
        tunnel.notifyOnConnect = store.settings.notifyOnConnect
        if store.settings.notifyOnConnect {
            NotificationManager.requestAuthorization()
        }

        await tunnel.loadManager()
        await SubscriptionService.refreshDue(store)

        // Geo databases only matter for presets that reference geosite:/geoip:.
        if store.settings.routingPreset.needsGeoAssets, !GeoAssetManager.shared.hasAssets {
            await GeoAssetManager.shared.download(source: store.settings.geoSource,
                                                  customGeoip: store.settings.customGeoipURL,
                                                  customGeosite: store.settings.customGeositeURL)
        }

        if store.settings.autoConnectOnLaunch,
           let server = store.server(withID: store.selectedServerID) {
            await tunnel.connect(to: server, settings: store.settings)
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
