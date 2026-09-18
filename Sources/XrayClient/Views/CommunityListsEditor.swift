import SwiftUI
import AppKit

/// Picks the community rule lists and says where a match in one of them goes.
///
/// Selected lists read as chips with their size on them, so it is obvious both
/// what is on and whether it has actually been downloaded yet. Everything else
/// sits behind one menu grouped the way the source groups it.
struct CommunityListsEditor: View {
    @Binding var selected: [String]
    @Binding var target: RuleTarget
    var onChange: () -> Void

    @Environment(Loc.self) private var loc
    private var lists = CommunityListManager.shared

    @State private var confirmClear = false

    // Spelled out because a private stored property makes the synthesized
    // memberwise initializer private too, which the Swift 6.2 toolchain on CI
    // rejects at the call site.
    init(selected: Binding<[String]>,
         target: Binding<RuleTarget>,
         onChange: @escaping () -> Void) {
        _selected = selected
        _target = target
        self.onChange = onChange
    }

    var body: some View {
        Form {
            Section {
                if selected.isEmpty {
                    empty
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(selected, id: \.self) { id in
                            chip(id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                addMenu
            } header: {
                Text(loc("Lists"))
            } footer: {
                Text(loc("Ready-made domain and subnet lists from the allow-domains project. Picking one adds a rule that matches everything in it."))
                    .font(.caption2)
            }

            Section {
                Picker(loc("Matches go to"), selection: $target) {
                    Text(loc("Proxy")).tag(RuleTarget.proxy)
                    Text(loc("Direct")).tag(RuleTarget.direct)
                    Text(loc("Block")).tag(RuleTarget.block)
                }
                .pickerStyle(.segmented)
                .onChange(of: target) { _, _ in onChange() }
                Text(loc("Your own rules are checked first, so a list never overrides a rule you wrote."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text(loc("Destination"))
            }

            Section {
                HStack {
                    status
                    Spacer()
                    Button(loc("Update now")) {
                        Task { await lists.refresh(ids: selected) }
                    }
                    .glassButton()
                    .disabled(selected.isEmpty || lists.isBusy)
                }
                if let error = lists.lastError {
                    Text(error).font(.caption2).foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                HStack {
                    Link(loc("Source on GitHub"),
                         destination: URL(string: CommunityListCatalog.homepage)!)
                        .font(.caption)
                    Spacer()
                    Button(loc("Clear cache"), role: .destructive) {
                        confirmClear = true
                    }
                    .buttonStyle(.borderless).font(.caption)
                }
            } header: {
                Text(loc("Cache"))
            } footer: {
                Text(loc("Lists refresh once a day on their own, and on demand here."))
                    .font(.caption2)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(loc("Delete the downloaded lists?"),
                            isPresented: $confirmClear) {
            Button(loc("Clear cache"), role: .destructive) {
                lists.clearCache()
                onChange()
            }
            Button(loc("Cancel"), role: .cancel) {}
        } message: {
            Text(loc("The lists you picked stay selected and are fetched again on the next update."))
        }
        .task { await lists.refreshDue(currentSettingsShim) }
    }

    /// `refreshDue` takes the settings so it can read the selection; this view
    /// only owns the two bindings, so it hands over the parts that matter.
    private var currentSettingsShim: AppSettings {
        var settings = AppSettings()
        settings.communityLists = selected
        settings.communityListTarget = target
        return settings
    }

    // MARK: - Pieces

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc("No lists selected.")).font(.callout)
            Text(loc("Pick one to route a whole service — Telegram, YouTube, Discord — without writing its domains out by hand."))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func chip(_ id: String) -> some View {
        let list = CommunityListCatalog.list(id: id)
        let cached = lists.cached(id)
        return HStack(spacing: 5) {
            if lists.isDownloading(id) {
                ProgressView().controlSize(.mini)
            } else if let cached, !cached.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(.green)
            } else {
                Image(systemName: "arrow.down.circle")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(loc(list?.title ?? id)).font(.caption)
            if let cached, !cached.isEmpty {
                Text(verbatim: "\(cached.entryCount)")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Button {
                let removed = id
                selected.removeAll { $0 == removed }
                onChange()
            } label: {
                Image(systemName: "xmark.circle.fill").font(.caption2)
            }
            .buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.secondary.opacity(0.14), in: Capsule())
    }

    private var addMenu: some View {
        Menu {
            ForEach(CommunityList.Category.allCases) { category in
                let available = CommunityListCatalog.lists(in: category)
                    .filter { !selected.contains($0.id) }
                if !available.isEmpty {
                    Section(loc(category.title)) {
                        ForEach(available) { list in
                            Button(loc(list.title)) { add(list.id) }
                        }
                    }
                }
            }
            if selected.count < CommunityListCatalog.all.count {
                Divider()
                Button(loc("Add all services")) {
                    for list in CommunityListCatalog.lists(in: .service) {
                        add(list.id)
                    }
                }
            }
        } label: {
            Label(loc("Add list"), systemImage: "plus.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(selected.count == CommunityListCatalog.all.count)
    }

    @ViewBuilder
    private var status: some View {
        if lists.isBusy {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(loc("Downloading…")).font(.caption).foregroundStyle(.secondary)
            }
        } else if selected.isEmpty {
            Text(loc("Nothing to download.")).font(.caption).foregroundStyle(.secondary)
        } else if let oldest = lists.oldestUpdate(among: selected) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(verbatim: "\(loc("Updated")) \(oldest.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(loc("Not downloaded yet")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func add(_ id: String) {
        guard !selected.contains(id) else { return }
        selected.append(id)
        onChange()
        Task { await lists.refresh(ids: [id]) }
    }
}
