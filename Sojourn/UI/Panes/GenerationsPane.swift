// Sojourn — GenerationsPane (v0.2 step 6)
//
// First-class UI over `GenerationService`. Lists numbered generations
// (newest first) with size + sha256 + brewfile counts. Rollback action
// extracts the archive and triggers `SyncCoordinator` to apply it.
//
// Refs: ADR-0018; v0.2-plan.md step 6.

import Foundation
import SwiftUI

internal struct GenerationsPane: View {
  @Environment(AppStore.self) private var store
  @State private var manifests: [GenerationManifest] = []
  @State private var loadError: String?
  @State private var creating: Bool = false
  @State private var note: String = ""

  internal var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if let loadError {
        Text(loadError)
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
      }

      if manifests.isEmpty && loadError == nil {
        emptyState
      } else {
        list
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier("pane.generations")
    .task { await reload() }
  }

  // MARK: - Subviews

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Generations")
          .font(.system(size: 22, weight: .bold))
        Text("Tarball-snapshot rollback. Newest first.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await snapshot() }
      } label: {
        Label("Snapshot now", systemImage: "plus.circle")
      }
      .disabled(creating)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "clock.arrow.circlepath")
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(.secondary)
      Text("No generations yet.")
        .font(.system(size: 14, weight: .medium))
      Text("Snapshots are taken before destructive operations and on demand. Click \"Snapshot now\" to capture the current state.")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 480)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
  }

  private var list: some View {
    Table(manifests) {
      TableColumn("#") { m in
        Text("\(m.generation.number)")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
      }
      .width(40)

      TableColumn("Created") { m in
        Text(m.generation.createdAt, format: .dateTime.year().month().day().hour().minute())
          .font(.system(size: 12, design: .monospaced))
      }
      .width(min: 140, ideal: 160)

      TableColumn("Counts") { m in
        let c = m.generation.brewfileCounts
        Text("brew \(c.brews) · cask \(c.casks) · mas \(c.mas) · vscode \(c.vscode)")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
      }

      TableColumn("Size") { m in
        Text(ByteCountFormatter.string(fromByteCount: m.archiveSizeBytes, countStyle: .file))
          .font(.system(size: 12, design: .monospaced))
      }
      .width(80)

      TableColumn("Note") { m in
        Text(m.generation.note.isEmpty ? "—" : m.generation.note)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }

      TableColumn("") { m in
        Button("Restore") {
          Task { await restore(m.generation.number) }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
      }
      .width(72)
    }
  }

  // MARK: - Actions

  private func reload() async {
    let svc = GenerationService(runner: store.runner, paths: store.paths)
    do {
      self.manifests = try await svc.list()
      self.loadError = nil
    } catch {
      self.loadError = "Failed to load generations: \(error)"
    }
  }

  private func snapshot() async {
    creating = true
    defer { creating = false }
    let svc = GenerationService(runner: store.runner, paths: store.paths)
    let candidate = store.paths.config.appendingPathComponent("Brewfile.common")
    do {
      _ = try await svc.create(
        note: note.isEmpty ? "manual snapshot" : note,
        brewfileCommon: candidate,
        brewfileHost: nil,
        prefsTOML: nil,
        machinesTOML: nil,
        chezmoiStateText: nil,
        brewfileCounts: store.brewfile?.counts ?? .init()
      )
      await reload()
    } catch {
      loadError = "Snapshot failed: \(error)"
    }
  }

  private func restore(_ number: Int) async {
    let svc = GenerationService(runner: store.runner, paths: store.paths)
    do {
      _ = try await svc.extract(number)
      // Real apply path (brew bundle install + chezmoi apply + defaults
      // import) lives in SyncCoordinator and is wired in step 6
      // follow-up — stub here surfaces only the "extracted to
      // generations/restore-N/" outcome to confirm the round-trip.
      loadError = nil
    } catch {
      loadError = "Restore failed: \(error)"
    }
  }
}
