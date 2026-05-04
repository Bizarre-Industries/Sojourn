// Sojourn — GitServiceInboundCommitsTests
//
// Parser-only unit tests for `GitService.parseInboundCommits` against a
// checked-in fixture under `SojournTests/Fixtures/git/inbound-commits.txt`.
// Avoids spawning git in unit tests — that's covered by
// ConflictResolverTests' end-to-end suite. Per CLAUDE.md test rule
// "Subprocess invocation tested via parser-only unit tests".
//
// Refs: ADR-0026 multi-machine conflict UX (200-commit cap amendment).

import Testing
import Foundation
@testable import Sojourn

struct GitServiceInboundCommitsTests {
  private func fixture(_ name: String) throws -> String {
    guard let url = Bundle.sojournFixtureURL(
      name: "git/\(name)",
      ext: "txt"
    ) else {
      Issue.record("Fixture not found in bundle: git/\(name).txt")
      return ""
    }
    return try String(contentsOf: url, encoding: .utf8)
  }

  @Test
  func parses_threeCommitFixture() throws {
    let raw = try fixture("inbound-commits")
    let commits = GitService.parseInboundCommits(raw)
    #expect(commits.count == 3)
  }

  @Test
  func parses_shaAndAuthorAndSubject() throws {
    let raw = try fixture("inbound-commits")
    let commits = GitService.parseInboundCommits(raw)
    let first = try #require(commits.first)
    #expect(first.sha == "a1b2c3d4e5f6789012345678901234567890abcd")
    #expect(first.author == "Alice Engineer")
    #expect(first.subject == "feat: add containers panel detection")
    #expect(first.shortSHA == "a1b2c3d")
  }

  @Test
  func parses_shortstatLine() throws {
    let raw = try fixture("inbound-commits")
    let commits = GitService.parseInboundCommits(raw)
    let first = try #require(commits.first)
    #expect(first.filesChanged == 3)
    #expect(first.insertions == 120)
    #expect(first.deletions == 4)
  }

  @Test
  func parses_iso8601Date() throws {
    let raw = try fixture("inbound-commits")
    let commits = GitService.parseInboundCommits(raw)
    let first = try #require(commits.first)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let expected = try #require(formatter.date(from: "2026-05-04T12:00:00+00:00"))
    #expect(first.date == expected)
  }

  @Test
  func parses_insertionsOnlyShortstat() throws {
    let raw = try fixture("inbound-commits")
    let commits = GitService.parseInboundCommits(raw)
    let third = try #require(commits.dropFirst(2).first)
    #expect(third.insertions == 8)
    #expect(third.deletions == 0)
  }

  @Test
  func emptyInput_returnsEmptyList() {
    #expect(GitService.parseInboundCommits("").isEmpty)
  }

  @Test
  func malformedHeader_skipped() {
    let raw = "this is not a tab-separated header line"
    #expect(GitService.parseInboundCommits(raw).isEmpty)
  }
}
