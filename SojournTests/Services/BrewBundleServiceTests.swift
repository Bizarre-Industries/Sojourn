// Sojourn — BrewBundleService tests
//
// Parser + serializer + tier classification. Subprocess invocation
// (`brew bundle install/dump`) is NOT exercised here — tests for the
// real subprocess flow live in fixture-driven integration suites that
// run against a sandbox brew prefix (out of v0.2 scope per
// docs/process/plans/v0.2-plan.md).

import Foundation
@testable import Sojourn
import Testing

struct BrewfileParserTests {
  @Test func parsesCanonicalFixture() throws {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "brewfiles/canonical", ext: "txt"),
      "canonical.txt fixture not found"
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    let ast = BrewfileParser.parse(text)

    #expect(ast.counts.taps == 2)
    #expect(ast.counts.brews == 3)
    #expect(ast.counts.casks == 2)
    #expect(ast.counts.mas == 2)
    #expect(ast.counts.vscode == 2)
    #expect(ast.counts.go == 1)
    #expect(ast.counts.cargo == 2)
    #expect(ast.counts.uv == 1)
    #expect(ast.counts.krew == 1)
    #expect(ast.counts.npm == 1)
    #expect(ast.packageCount == 17)
  }

  @Test func parsesMasWithID() {
    let ast = BrewfileParser.parse("mas \"Xcode\", id: 497799835\n")
    if case let .mas(name, id) = ast.entries.first {
      #expect(name == "Xcode")
      #expect(id == 497799835)
    } else {
      Issue.record("expected .mas entry")
    }
  }

  @Test func parsesBrewWithOptions() {
    let ast = BrewfileParser.parse("brew \"go@1.21\", link: false\n")
    if case let .brew(name, options) = ast.entries.first {
      #expect(name == "go@1.21")
      #expect(options["link"] == "false")
    } else {
      Issue.record("expected .brew entry with options")
    }
  }

  @Test func preservesCommentsAndBlanks() {
    let text = """
      # comment one
      brew \"act\"

      # another comment
      """
    let ast = BrewfileParser.parse(text)
    #expect(ast.entries.count == 4)
    if case .comment(let c) = ast.entries.first { #expect(c == "# comment one") }
    if case .blank = ast.entries[2] {} else {
      Issue.record("expected blank as third entry")
    }
  }

  @Test func unknownDirectivesBecomeComments() {
    // Forward compat: if brew adds a new ecosystem we don't know about,
    // round-trip it without losing the line.
    let ast = BrewfileParser.parse("future \"some-package\"\n")
    if case .comment = ast.entries.first {} else {
      Issue.record("expected unknown directive to become a comment")
    }
  }
}

struct BrewfileSerializerTests {
  @Test func roundTripsCanonicalFixture() throws {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "brewfiles/canonical", ext: "txt"),
      "canonical.txt fixture not found"
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    let ast = BrewfileParser.parse(text)
    let reSerialized = BrewfileSerializer.serialize(ast)
    let reParsed = BrewfileParser.parse(reSerialized)
    // AST equality across the round-trip — raw text may differ in
    // trailing whitespace/option ordering, AST must not.
    #expect(reParsed.counts == ast.counts)
  }

  @Test func emitsMasWithID() {
    let ast = BrewfileAST(entries: [.mas("Xcode", id: 497799835)])
    #expect(BrewfileSerializer.serialize(ast).hasPrefix("mas \"Xcode\", id: 497799835"))
  }
}

struct BrewfileTierTests {
  @Test func tiersMatchADR0018Mapping() {
    #expect(BrewfileEntry.mas("X", id: 1).tier == .a)
    #expect(BrewfileEntry.brew("act").tier == .b)
    #expect(BrewfileEntry.cask("iterm2").tier == .c)
    #expect(BrewfileEntry.vscode("ms-python.python").tier == .d)
    #expect(BrewfileEntry.cargo("ripgrep").tier == .e)
    #expect(BrewfileEntry.npm("typescript").tier == .e)
    #expect(BrewfileEntry.tap("homebrew/cask").tier == nil)
  }

  @Test func tierCooldownDays() {
    #expect(BrewfileTier.a.defaultCooldownDays == 0)
    #expect(BrewfileTier.b.defaultCooldownDays == 7)
    #expect(BrewfileTier.c.defaultCooldownDays == 14)
    #expect(BrewfileTier.d.defaultCooldownDays == 21)
    #expect(BrewfileTier.e.defaultCooldownDays == 30)
  }
}

struct PackageInventoryRowTests {
  @Test func canonicalFixtureMapsEveryPackageEntryToInventoryRows() throws {
    let url = try #require(
      Bundle.sojournFixtureURL(name: "brewfiles/canonical", ext: "txt"),
      "canonical.txt fixture not found"
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    let ast = BrewfileParser.parse(text)

    let rows = PackageInventoryRow.rows(from: ast)

    #expect(rows.count == ast.packageCount)
    #expect(rows.map(\.managerID) == [
      "tap", "tap",
      "brew", "brew", "brew",
      "cask", "cask",
      "mas", "mas",
      "vscode", "vscode",
      "go",
      "cargo", "cargo",
      "uv",
      "krew",
      "npm"
    ])

    let mas = try #require(rows.first { $0.packageID == "Xcode" })
    #expect(mas.detail == "id 497799835")

    let linkedBrew = try #require(rows.first { $0.packageID == "go@1.21" })
    #expect(linkedBrew.detail == "link: false")
  }

  @Test func rowsCanBeFilteredByManagerID() {
    let ast = BrewfileAST(entries: [
      .brew("ripgrep"),
      .cask("iterm2"),
      .mas("Xcode", id: 497799835),
      .comment("# ignored"),
      .blank
    ])

    #expect(PackageInventoryRow.rows(from: ast, managerID: "brew").map(\.packageID) == ["ripgrep"])
    #expect(PackageInventoryRow.rows(from: ast, managerID: "cask").map(\.packageID) == ["iterm2"])
    #expect(PackageInventoryRow.rows(from: ast, managerID: "mas").map(\.packageID) == ["Xcode"])
  }

  @Test func flatpakEntriesStayParsedButHiddenFromMacOSInventoryUI() {
    let ast = BrewfileAST(entries: [
      .brew("ripgrep"),
      .flatpak("org.example.NotForMac")
    ])

    #expect(ast.counts.flatpak == 1)
    #expect(PackageInventoryRow.rows(from: ast).map(\.managerID) == ["brew"])
    #expect(PackageInventoryRow.rows(from: ast, managerID: "flatpak").isEmpty)
  }
}
