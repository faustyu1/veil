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
    @State private var runningOnly = false
    @State private var chosen: Set<String> = []

    private var results: [ProcessEntry] {
        let base = catalog.search(query)
        return runningOnly ? base.filter(\.isRunning) : base
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
        .task {
            chosen = Set(selection)
            await catalog.reload()
        }
    }

    private var header: some View {
        HStack {
            Text(loc("Choose applications")).font(.title3).bold()
            Spacer()
            if catalog.isLoading { ProgressView().controlSize(.small) }
        }
        .padding()
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(loc("Search by name, executable or bundle id"), text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
            }
            Toggle(loc("Running"), isOn: $runningOnly)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(results) { entry in
                    row(entry)
                    Divider().padding(.leading, 44)
                }
            }
        }
    }

    private func row(_ entry: ProcessEntry) -> some View {
        let isOn = chosen.contains(entry.executableName)
        return Button {
            if isOn {
                chosen.remove(entry.executableName)
            } else {
                chosen.insert(entry.executableName)
            }
        } label: {
            HStack(spacing: 10) {
                icon(for: entry)
                    .resizable().frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(entry.displayName).lineLimit(1)
                        if entry.isRunning {
                            Circle().fill(.green).frame(width: 5, height: 5)
                        }
                    }
                    // Only worth the line when it is not the same word twice.
                    if entry.nameDiffersFromExecutable {
                        Text(entry.executableName)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
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
                 : "\(chosen.count) " + loc("selected"))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(loc("Cancel")) { dismiss() }
            Button(loc("Add")) {
                selection = chosen.sorted()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .glassProminentButton()
        }
        .padding()
    }
}
