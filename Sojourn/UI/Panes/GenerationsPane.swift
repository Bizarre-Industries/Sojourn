// Sojourn — GenerationsPane

import SwiftUI

struct GenerationsPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if let error = store.generationLoadError {
        ContentUnavailableView(
          "Could not load generations",
          systemImage: "exclamationmark.triangle",
          description: Text("Check that the Sojourn generations folder in Application Support is readable, then refresh. Cause: \(error)")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if store.generations.isEmpty {
        ContentUnavailableView(
          "No generations yet",
          systemImage: "clock.arrow.circlepath",
          description: Text("Snapshots appear here after Sojourn creates a pre-operation generation.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(store.generations) { manifest in
          generationRow(manifest)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
      }
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
    .accessibilityIdentifier("pane.generations")
    .task {
      await store.refreshGenerations()
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Generations")
          .font(.title2.weight(.semibold))
        Text("Retained tarball snapshots under Application Support.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        Task { await store.refreshGenerations() }
      } label: {
        Label("Refresh", systemImage: "arrow.clockwise")
      }
    }
  }

  private func generationRow(_ manifest: GenerationManifest) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "archivebox")
        .foregroundStyle(.secondary)
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text("Generation \(manifest.generation.number)")
          .font(.callout.weight(.semibold))
        Text(manifest.generation.note.isEmpty ? manifest.generation.tag : manifest.generation.note)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text(generationMetadata(for: manifest))
          .font(.caption2.monospaced())
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(Self.dateFormatter.localizedString(for: manifest.generation.createdAt, relativeTo: Date()))
          .font(.caption)
        Text("\(Self.byteFormatter.string(fromByteCount: manifest.archiveSizeBytes)) · \(String(manifest.sha256.prefix(12)))")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
        Text(brewfileCounts(for: manifest.generation.brewfileCounts))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
  }

  private func generationMetadata(for manifest: GenerationManifest) -> String {
    let commit = manifest.generation.chezmoiCommit.map {
      " · commit \(String($0.prefix(12)))"
    } ?? ""
    return "\(manifest.generation.tag)\(commit)"
  }

  private func brewfileCounts(for counts: BrewfileAST.Counts) -> String {
    let total = counts.taps + counts.brews + counts.casks + counts.mas
      + counts.vscode + counts.go + counts.cargo + counts.uv
      + counts.krew + counts.npm + counts.flatpak
    return "\(total) entries · \(counts.brews) brews · \(counts.casks) casks · \(counts.mas) apps"
  }

  private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter
  }()

  private static let dateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()
}
