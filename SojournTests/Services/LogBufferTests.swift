import Foundation
import Testing
@testable import Sojourn

struct LogBufferTests {
  @Test func appendAndSnapshot() async {
    let buffer = LogBuffer()
    await buffer.append(LogLine(stream: .stdout, text: "hello"))
    await buffer.append(LogLine(stream: .stderr, text: "err"))
    let snap = await buffer.snapshot()
    #expect(snap.count == 2)
    #expect(snap[0].text == "hello")
    #expect(snap[1].stream == .stderr)
  }

  @Test func feedSplitsOnNewline() async {
    let buffer = LogBuffer()
    await buffer.feed(StreamChunk(
      stream: .stdout,
      data: Data("line1\nline2\npart".utf8)
    ))
    var snap = await buffer.snapshot()
    #expect(snap.count == 2)
    #expect(snap[0].text == "line1")
    #expect(snap[1].text == "line2")

    await buffer.feed(StreamChunk(
      stream: .stdout,
      data: Data("ial\nline3\n".utf8)
    ))
    snap = await buffer.snapshot()
    #expect(snap.count == 4)
    #expect(snap[2].text == "partial")
    #expect(snap[3].text == "line3")
  }

  @Test func flushPartialsDumpsTrailing() async {
    let buffer = LogBuffer()
    await buffer.feed(StreamChunk(stream: .stdout, data: Data("no-newline".utf8)))
    await buffer.flushPartials()
    let snap = await buffer.snapshot()
    #expect(snap.count == 1)
    #expect(snap[0].text == "no-newline")
  }

  @Test func capacityDrops() async {
    let buffer = LogBuffer(capacity: 100)
    for i in 0..<150 {
      await buffer.append(LogLine(stream: .stdout, text: "line\(i)"))
    }
    let snap = await buffer.snapshot()
    #expect(snap.count <= 100)
    #expect(snap.last?.text == "line149")
  }
}
