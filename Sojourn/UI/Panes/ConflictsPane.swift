// Sojourn — ConflictsPane
//
// Renders the ConflictResolver state. Five sub-states map to distinct
// UI surfaces:
//   .clean            → empty state ("No inbound commits — main is clean")
//   .detecting        → progress spinner
//   .conflictPending  → inbound commit list + 3-button choice modal
//   .resolving        → progress spinner labeled with chosen action
//   .resolved         → success surface
//   .blockedFromPush  → reason + Pull-now button
//   .failed           → error surface + Retry
//
// Refs: ADR-0026 multi-machine conflict UX (copy spec amendments).

import SwiftUI

struct ConflictsPane: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      if let resolver = store.conflictResolver {
        content(for: resolver)
      } else {
        PaneEmptyState(
          eyebrow: "CONFLICTS · SyncCoordinator · resolver",
          title: "SYNC NOT CONFIGURED.",
          subtitle: "Configure a sync remote in Settings to enable conflict detection."
        )
      }
    }
    .accessibilityIdentifier("pane.conflicts")
  }

  @ViewBuilder
  private func content(for resolver: ConflictResolver) -> some View {
    switch resolver.state {
    case .clean:
      PaneEmptyState(
        eyebrow: "CONFLICTS · clean",
        title: "ALL CLEAR.",
        subtitle: "No inbound commits — main is clean. Conflicts surface here when another machine has pushed commits you have not yet pulled."
      )

    case .detecting:
      VStack(spacing: 16) {
        ProgressView()
        Text("Checking for inbound commits…")
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    case .conflictPending(let commits):
      pendingView(commits: commits, resolver: resolver)

    case .resolving(let choice):
      VStack(spacing: 16) {
        ProgressView()
        Text(progressLabel(for: choice))
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

    case .resolved:
      PaneEmptyState(
        eyebrow: "CONFLICTS · resolved",
        title: "RESOLVED.",
        subtitle: "Inbound commits applied. Push is unblocked."
      )

    case .blockedFromPush(let reason):
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "CONFLICTS · push blocked")
        Text("PUSH BLOCKED.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text(reason)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
        Button("Re-check inbound commits") {
          Task { await resolver.detect() }
        }
        Spacer(minLength: 0)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)

    case .failed(let msg):
      VStack(alignment: .leading, spacing: 16) {
        EyebrowLabel(text: "CONFLICTS · failed")
        Text("SYNC ERROR.")
          .font(.bzrStencil(size: 30, weight: .heavy))
          .foregroundStyle(Color.txtPrimary)
        Text(msg)
          .font(.bzrBody(size: 13))
          .foregroundStyle(Color.txtSecondary)
        Button("Retry detection") {
          Task { await resolver.detect() }
        }
        Spacer(minLength: 0)
      }
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func pendingView(
    commits: [InboundCommit],
    resolver: ConflictResolver
  ) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      EyebrowLabel(text: "CONFLICTS · inbound · \(commits.count)")
      Text("REMOTE MOVED. \(commits.count) COMMITS INBOUND.")
        .font(.bzrStencil(size: 24, weight: .heavy))
        .foregroundStyle(Color.txtPrimary)
        .lineLimit(2)
      Text("Resolve before pushing.")
        .font(.bzrBody(size: 13))
        .foregroundStyle(Color.txtSecondary)

      // ADR-0026: List with id: \.sha. Parsing happens in
      // GitService actor; the view body only renders.
      List(commits, id: \.sha) { commit in
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(commit.shortSHA)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(Color.txtSecondary)
            Text(commit.author)
              .font(.bzrBody(size: 12))
              .foregroundStyle(Color.txtSecondary)
            Spacer()
            Text(commit.date.formatted(.relative(presentation: .numeric)))
              .font(.bzrBody(size: 12))
              .foregroundStyle(Color.txtSecondary)
          }
          Text(commit.subject)
            .font(.bzrBody(size: 13))
            .foregroundStyle(Color.txtPrimary)
          Text("\(commit.filesChanged) files · +\(commit.insertions) / -\(commit.deletions)")
            .font(.bzrBody(size: 11))
            .foregroundStyle(Color.txtSecondary)
        }
        .padding(.vertical, 4)
      }
      .listStyle(.plain)
      .frame(minHeight: 200, maxHeight: .infinity)

      HStack(spacing: 12) {
        Button("Pull and rebase your work") {
          Task { await resolver.apply(.rebase) }
        }
        .buttonStyle(.borderedProminent)

        Button("Pull and merge") {
          Task { await resolver.apply(.merge) }
        }

        Spacer()

        Button("Cancel — leave local alone") {
          Task { await resolver.apply(.abort) }
        }
        .foregroundStyle(Color.txtSecondary)
      }
    }
    .padding(28)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func progressLabel(for choice: ConflictResolver.Choice) -> String {
    switch choice {
    case .rebase: return "Pulling and rebasing your work…"
    case .merge:  return "Pulling and merging…"
    case .abort:  return "Cancelling…"
    }
  }
}
