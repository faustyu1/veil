import SwiftUI

/// Routing editor: preset picker, geo database source, and the custom ordered
/// rule list. Rules are the same `RoutingRule` model the desktop app compiles
/// into Xray `field` rules.
struct RoutingView: View {
    @Environment(ServerStore.self) private var store
    @Environment(Loc.self) private var loc

    @State private var geo = GeoAssetManager.shared
    /// Drives edit mode by hand instead of using `EditButton`: system controls
    /// draw their own title from the *device* language, which would ignore the
    /// language picked in this app's settings.
    @State private var isEditing = false

    var body: some View {
        @Bindable var store = store

        Form {
            Section(loc("Preset")) {
                Picker(loc("Preset"), selection: $store.settings.routingPreset) {
                    ForEach(RoutingPreset.allCases) { Text(loc($0.title)).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text(loc(store.settings.routingPreset.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(loc("Blocking")) {
                Toggle(loc("Block ads"), isOn: $store.settings.blockAds)
            }

            if store.settings.routingPreset.needsGeoAssets || store.settings.blockAds {
                Section {
                    Picker(loc("Source"), selection: $store.settings.geoSource) {
                        ForEach(GeoAssetSource.allCases) { Text(loc($0.title)).tag($0) }
                    }
                    if store.settings.geoSource == .custom {
                        TextField("geoip.dat URL", text: $store.settings.customGeoipURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        TextField("geosite.dat URL", text: $store.settings.customGeositeURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Button {
                        Task {
                            await geo.download(source: store.settings.geoSource,
                                               customGeoip: store.settings.customGeoipURL,
                                               customGeosite: store.settings.customGeositeURL)
                        }
                    } label: {
                        if geo.isDownloading {
                            HStack { ProgressView(); Text(loc("Downloading…")) }
                        } else {
                            Label(loc("Download geo databases"), systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(geo.isDownloading)
                } header: {
                    Text(loc("Geo databases"))
                } footer: {
                    if let error = geo.lastError {
                        Text(error).foregroundStyle(.red)
                    } else if geo.hasAssets {
                        Text(loc("Installed."))
                    } else {
                        Text(loc("geosite:/geoip: rules need these files."))
                    }
                }
            }

            if store.settings.routingPreset == .custom {
                Section(loc("Custom rules")) {
                    ForEach($store.settings.customRules) { $rule in
                        RuleEditor(rule: $rule)
                    }
                    .onDelete { offsets in
                        store.settings.customRules.remove(atOffsets: offsets)
                        store.save()
                    }
                    .onMove { source, destination in
                        store.settings.customRules.move(fromOffsets: source,
                                                        toOffset: destination)
                        store.save()
                    }

                    Button {
                        store.settings.customRules.append(
                            RoutingRule(name: loc("New rule"), outbound: .direct))
                        store.save()
                    } label: {
                        Label(loc("Add rule"), systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle(loc("Routing"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .toolbar {
            if store.settings.routingPreset == .custom {
                Button(isEditing ? loc("Done") : loc("Edit")) { isEditing.toggle() }
            }
        }
        .onDisappear { store.save() }
    }
}

/// One rule: where it sends traffic, and the domain / IP / port it matches.
private struct RuleEditor: View {
    @Environment(Loc.self) private var loc
    @Binding var rule: RoutingRule

    @State private var domainsText = ""
    @State private var ipsText = ""

    var body: some View {
        DisclosureGroup {
            Picker(loc("Outbound"), selection: $rule.outbound) {
                ForEach(RuleOutbound.allCases) { Text(loc($0.title)).tag($0) }
            }
            .pickerStyle(.segmented)

            TextField(loc("Name"), text: $rule.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(loc("Domains")).font(.caption).foregroundStyle(.secondary)
                TextField("example.com, geosite:cn", text: $domainsText, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: domainsText) { _, value in
                        rule.domains = Self.split(value)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(loc("IPs")).font(.caption).foregroundStyle(.secondary)
                TextField("10.0.0.0/8, geoip:ru", text: $ipsText, axis: .vertical)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: ipsText) { _, value in
                        rule.ips = Self.split(value)
                    }
            }

            TextField(loc("Port (optional)"), text: $rule.port)
                .keyboardType(.numbersAndPunctuation)

            Toggle(loc("Enabled"), isOn: $rule.enabled)
        } label: {
            HStack {
                Text(rule.name.isEmpty ? loc("Untitled rule") : rule.name)
                Spacer()
                Text(loc(rule.outbound.title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(rule.enabled ? 1 : 0.5)
        }
        .onAppear {
            domainsText = rule.domains.joined(separator: ", ")
            ipsText = rule.ips.joined(separator: ", ")
        }
    }

    private static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
