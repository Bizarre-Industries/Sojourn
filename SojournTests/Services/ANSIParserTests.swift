import Foundation
import Testing
@testable import Sojourn

struct ANSIParserTests {
  @Test func plainTextPassesThrough() {
    let runs = ANSIParser().parse("hello world")
    #expect(runs.count == 1)
    #expect(runs[0].text == "hello world")
    #expect(runs[0].attrs == .plain)
  }

  @Test func basicForegroundColor() {
    let input = "\u{1B}[31mred\u{1B}[0m plain"
    let runs = ANSIParser().parse(input)
    #expect(runs.count == 2)
    #expect(runs[0].text == "red")
    #expect(runs[0].attrs.foreground == .red)
    #expect(runs[1].text == " plain")
    #expect(runs[1].attrs == .plain)
  }

  @Test func boldPlusColor() {
    let input = "\u{1B}[1;32mbold-green\u{1B}[0m"
    let runs = ANSIParser().parse(input)
    #expect(runs.count == 1)
    #expect(runs[0].attrs.bold)
    #expect(runs[0].attrs.foreground == .green)
  }

  @Test func brightColors() {
    let input = "\u{1B}[91mbright-red"
    let runs = ANSIParser().parse(input)
    #expect(runs[0].attrs.foreground == .brightRed)
  }

  @Test func xtermIndexed256() {
    let input = "\u{1B}[38;5;202morange"
    let runs = ANSIParser().parse(input)
    #expect(runs[0].attrs.foreground == .indexed(202))
  }

  @Test func trueColorRGB() {
    let input = "\u{1B}[38;2;10;20;30mrgb"
    let runs = ANSIParser().parse(input)
    #expect(runs[0].attrs.foreground == .rgb(r: 10, g: 20, b: 30))
  }

  @Test func cursorSequencesAreStripped() {
    let input = "\u{1B}[?25h\u{1B}[Khello"
    let runs = ANSIParser().parse(input)
    #expect(runs.count == 1)
    #expect(runs[0].text == "hello")
  }

  @Test func statefulAcrossChunks() {
    var parser = StatefulANSIParser()
    parser.feed("\u{1B}[4mund")
    parser.feed("erline\u{1B}[0m done")
    let runs = parser.drain()
    #expect(runs.count == 2)
    #expect(runs[0].attrs.underline)
    #expect(runs[0].text == "underline")
    #expect(runs[1].attrs == .plain)
    #expect(runs[1].text == " done")
  }
}
