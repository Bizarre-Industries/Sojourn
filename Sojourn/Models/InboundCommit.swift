// Sojourn — InboundCommit
//
// Value type representing one commit on `origin/<branch>` that has not yet
// been merged into the local branch. Produced by
// `GitService.inboundCommits(...)` and consumed by `ConflictResolver` +
// `ConflictsPane`.
//
// Refs: ADR-0026 (multi-machine conflict UX);
//       docs/process/plans/v0.3-plan.md stage 5.

import Foundation

internal struct InboundCommit: Sendable, Hashable, Identifiable {
  internal let sha: String
  internal let author: String
  internal let date: Date
  internal let subject: String
  internal let filesChanged: Int
  internal let insertions: Int
  internal let deletions: Int

  internal var id: String { sha }

  internal var shortSHA: String {
    String(sha.prefix(7))
  }

  internal init(
    sha: String,
    author: String,
    date: Date,
    subject: String,
    filesChanged: Int,
    insertions: Int,
    deletions: Int
  ) {
    self.sha = sha
    self.author = author
    self.date = date
    self.subject = subject
    self.filesChanged = filesChanged
    self.insertions = insertions
    self.deletions = deletions
  }
}
