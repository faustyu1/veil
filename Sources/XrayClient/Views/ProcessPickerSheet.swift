import SwiftUI
import AppKit

/// Picks applications for a rule, with search.
///
/// A rule matches on the *executable* name, which is frequently not the name
/// on the icon — Visual Studio Code runs as `Electron`, Safari's networking
/// happens in `com.apple.WebKit.Networking`. Typing that from memory is how
/// rules end up silently matching nothing, so the picker shows both and writes
/// the right one.
struct ProcessPickerSheet: View {
    /// Executable names already on the rule.
    @Binding var selection: [String]
    @Environment(\.dismiss) private var dismiss
    @Environment(Loc.self) private var loc

    @State private var catalog = ProcessCatalog.shared
    @State private var query = ""
    @State private var scope: Scope = .all
    @State private var chosen: Set<String> = []

    private enum Scope: Hashable { case all, running, picked }

    private var results: [ProcessEntry] {
        let base = catalog.search(query)
        switch scope {
        case .all:     return base
        case .running: return base.filter(\.isRunning)
        case .picked:  return base.filter { chosen.contains($0.executableName) }
        }
    }

    var body: some View {
        NavigationStack {
            list
                .safeAreaInset(edge: .top, spacing: 0) { scopePicker }
                .safeAreaInset(edge: .bottom, spacing: 0) { footer }
                .searchable(text: $query,
                            placement: .toolbar,
                            prompt: Text(loc("Search by name, executable or bundle id")))
                .navigationTitle(loc("Choose applications"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        if catalog.isLoading { ProgressView().controlSize(.small) }
                    }
                }
        }
        .frame(width: 540, height: 580)
        .task {
            chosen = Set(selection)
            await catalog.reload()
        }
    }

    private var scopePicker: some View {
        Picker("", selection: $scope) {
            Text(loc("All")).tag(Scope.all)
            Text(loc("Running")).tag(Scope.running)
            Text(loc("Selected")).tag(Scope.picked)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var list: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            ForEach(results) { entry in
                row(entry)
            }
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds(.enabled)
    }

    /// One native checkbox per application — the label carries the icon and the
    /// executable, so the thing being written into the rule is always visible.
    private func row(_ entry: ProcessEntry) -> some View {
        Toggle(isOn: Binding(
            get: { chosen.contains(entry.executableName) },
            set: { on in
                if on { chosen.insert(entry.executableName) }
                else { chosen.remove(entry.executableName) }
            }
        )) {
            HStack(spacing: 10) {
                icon(for: entry)
                    .resizable().frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(entry.displayName).lineLimit(1)
                        if entry.isRunning {
                            Circle().fill(.green).frame(width: 5, height: 5)
                                .help(loc("Running"))
                        }
                    }
                    // Only worth the line when it is not the same word twice.
                    if entry.nameDiffersFromExecutable {
                        Text(entry.executableName)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }

    private func icon(for entry: ProcessEntry) -> Image {
        let path = entry.bundlePath ?? entry.executablePath
        if FileManager.default.fileExists(atPath: path) {
            return Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        }
        return Image(nsImage: NSWorkspace.shared.icon(for: .unixExecutable))
    }

    private var footer: some View {
        HStack {
            Text(chosen.isEmpty
                 ? loc("Nothing selected")
                 : "\(loc("Selected")): \(chosen.count)")
                .font(.caption).foregroundStyle(.secondary)
            if !chosen.isEmpty {
                Button(loc("Clear")) { chosen.removeAll() }
                    .buttonStyle(.link).font(.caption)
            }
            Spacer()
            Button(loc("Cancel")) { dismiss() }
                .glassButton()
            Button(loc("Add")) {
                selection = chosen.sorted()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .glassProminentButton()
        }
        .padding(12)
        .background(.bar)
    }
}
