// MasHelper — service implementation
//
// Implements `MasHelperProtocol` by spawning `/opt/homebrew/bin/mas`
// as root and returning the exit code + captured streams.
//
// Per ADR-0024 + council 2026-05-03:
// - argv discipline: App Store IDs cross XPC as `NSNumber<UInt64>`,
//   validated `> 0` before reaching `Process`. `mas` is invoked
//   `Process(arguments: ["install", String(id)])` — array form,
//   never a shell-interpreted concatenated string.
// - Helper-side 600s subprocess cap (snapshot tier per JobRunner
//   timeout policy in v0.3-plan.md "Hard decisions"). Hung subprocess
//   gets SIGTERM then SIGKILL after 5s grace; client sees
//   `masHelperTimeoutExitCode`.
// - Every invocation logs to OSLog subsystem
//   `industries.bizarre.Sojourn.helper`.

import Foundation
import OSLog

internal final class MasHelperService: NSObject, MasHelperProtocol, @unchecked Sendable {
  private let log = Logger(
    subsystem: masHelperLogSubsystem,
    category: "mas-invocation"
  )

  // MARK: - MasHelperProtocol

  internal func install(
    appStoreID: NSNumber,
    withReply reply: @escaping (Int32, String, String) -> Void
  ) {
    let id = appStoreID.uint64Value
    guard id > 0 else {
      log.error("install rejected: appStoreID == 0")
      reply(masHelperInvalidInputExitCode, "", "invalid appStoreID 0")
      return
    }
    log.notice("install id=\(id)")
    runMas(args: ["install", String(id)], reply: reply)
  }

  internal func upgrade(
    appStoreIDs: [NSNumber],
    withReply reply: @escaping (Int32, String, String) -> Void
  ) {
    var args = ["upgrade"]
    for n in appStoreIDs {
      let id = n.uint64Value
      guard id > 0 else {
        log.error("upgrade rejected: appStoreIDs contained 0")
        reply(masHelperInvalidInputExitCode, "", "invalid appStoreID 0 in upgrade list")
        return
      }
      args.append(String(id))
    }
    log.notice("upgrade ids=\(appStoreIDs.count)")
    runMas(args: args, reply: reply)
  }

  internal func helperVersion(
    withReply reply: @escaping (String) -> Void
  ) {
    let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
    let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
    reply("\(version) (\(build))")
  }

  // MARK: - Private

  private func runMas(
    args: [String],
    reply: @escaping (Int32, String, String) -> Void
  ) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: masHelperToolPath)
    process.arguments = args

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
      try process.run()
    } catch {
      log.error("spawn failed: \(error.localizedDescription, privacy: .public)")
      reply(-1, "", "spawn failed: \(error.localizedDescription)")
      return
    }

    // Off-thread watchdog: SIGTERM at 600s, SIGKILL after 5s grace.
    let watchdog = DispatchQueue.global(qos: .utility)
    let timedOutBox = TimedOutBox()
    watchdog.asyncAfter(deadline: .now() + masHelperTimeoutSeconds) {
      guard process.isRunning else { return }
      timedOutBox.set()
      self.log.error("subprocess exceeded \(Int(masHelperTimeoutSeconds))s; SIGTERM")
      process.terminate()
      watchdog.asyncAfter(deadline: .now() + 5) {
        guard process.isRunning else { return }
        self.log.error("subprocess ignored SIGTERM; SIGKILL")
        kill(process.processIdentifier, SIGKILL)
      }
    }

    process.waitUntilExit()

    // Drain pipes after exit (both ends closed; readDataToEndOfFile
    // returns whatever's buffered).
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    let stdout = String(decoding: stdoutData, as: UTF8.self)
    let stderr = String(decoding: stderrData, as: UTF8.self)

    if timedOutBox.value {
      reply(masHelperTimeoutExitCode, stdout, stderr)
      return
    }

    let code = process.terminationStatus
    log.info("subprocess exited code=\(code)")
    reply(code, stdout, stderr)
  }
}

/// Tiny lock-protected bool for the watchdog → main path. Avoids
/// importing a heavier dispatch primitive for one flag.
private final class TimedOutBox: @unchecked Sendable {
  private let lock = NSLock()
  private var flag = false

  func set() {
    lock.lock(); defer { lock.unlock() }
    flag = true
  }

  var value: Bool {
    lock.lock(); defer { lock.unlock() }
    return flag
  }
}
