// Sojourn — CleanupPane

import SwiftUI

struct CleanupPane: View {
  @Environment(AppStore.self) private var store
  @State private var scanning = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        EyebrowLabel(text: "CLEANUP · CleanupService · scan · trash · 30d retention")
          .padding(.top, 8)
        Text("ORPHAN CANDIDATES.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text("Rescan the home directory against the bundled-owners registry; anything left over without an owning package is a candidate for the Trash. Each move is reversible from Finder for 30 days.")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
          .frame(maxWidth: 64 * 9, alignment: .leading)

        HStack(spacing: 8) {
          Button {
            Task {
              scanning = true
              await store.rescanOrphans()
              scanning = false
            }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold))
              Text(scanning ? "Scanning…" : "Scan home")
            }
          }
          .buttonStyle(GlassCapsuleButtonStyle())
          .disabled(scanning)
          .accessibilityIdentifier("pane.cleanup.scan")

          Spacer()

          Button {
            Task {
              for orphan in store.orphans {
                _ = try? await store.cleanup.trash(orphan)
              }
              await store.rescanOrphans()
            }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
              Text("Move \(store.orphans.count) to Trash")
            }
          }
          .buttonStyle(GlassDangerButtonStyle())
          .disabled(store.orphans.isEmpty)
          .help("Each candidate is moved to the Finder Trash via NSFileManager.trashItem. Reversible for 30 days.")
        }

        if store.orphans.isEmpty {
          BzrCard(eyebrow: "ORPHANS") {
            VStack(alignment: .leading, spacing: 6) {
              Text(scanning ? "Scanning…" : "No orphan candidates")
                .font(.bzrBody(size: 13, weight: .semibold))
                .foregroundStyle(Color.txtPrimary)
              if !scanning {
                Text("Run a scan above. The bundled-owners registry maps ~50 common home-directory paths to their owning Homebrew formulae or App Store apps; anything outside the registry without an owner is flagged here.")
                  .font(.bzrBody(size: 12))
                  .foregroundStyle(Color.txtSecondary)
              }
            }
          }
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(store.orphans) { orphan in
              orphanRow(orphan)
            }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("pane.cleanup")
  }

  @ViewBuilder
  private func orphanRow(_ orphan: OrphanCandidate) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "doc")
        .font(.system(size: 11))
        .foregroundStyle(Color.txtTertiary)
      Text(orphan.path.path)
        .font(.bzrMono(size: 11))
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      Text(ByteCountFormatter.string(fromByteCount: orphan.sizeBytes, countStyle: .file))
        .font(.bzrMono(size: 10))
        .foregroundStyle(Color.txtTertiary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .overlay(
      Rectangle().fill(Color.hairline).frame(height: 0.5),
      alignment: .bottom
    )
  }
}
