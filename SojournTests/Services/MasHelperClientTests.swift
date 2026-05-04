// Sojourn — MasHelperClient + MasService tests (v0.3, stage 4)
//
// Covers:
// - MasHelperProtocol shared constants (mach service name, bundle id,
//   plist name, sentinel exit codes, timeout).
// - MasInvocationResult convenience accessors.
// - MasHelperClient input validation (UInt64 > 0, no zero IDs in
//   upgrade list).
// - MasHelperClientError descriptions.
//
// XPC contract round-trip (real privileged daemon) is NOT exercised
// here — it requires a notarized build + `SMAppService.register()`
// approval flow. That smoke check belongs to the v0.3.0 release VM
// run per `docs/process/plans/v0.3-plan.md` stage 4 exit criteria.
//
// Refs: docs/decisions/0024-mas-touch-id-privileged-helper.md;
//       Sojourn/Services/MasHelperProtocol.swift.

import Foundation
@testable import Sojourn
import Testing

struct MasHelperProtocolConstantsTests {
  @Test func machServiceNameMatchesLaunchdPlist() {
    #expect(masHelperMachServiceName == "industries.bizarre.Sojourn.helper.mach")
  }

  @Test func bundleIdentifierMatchesCaskUninstall() {
    // Cask uninstall stanza references this id under launchctl: + delete:.
    #expect(masHelperBundleIdentifier == "industries.bizarre.Sojourn.helper")
  }

  @Test func launchdPlistName() {
    #expect(masHelperLaunchdPlistName == "industries.bizarre.Sojourn.helper.plist")
  }

  @Test func timeoutMatches600SecondsSnapshotTier() {
    // Per JobRunner snapshot tier in v0.3-plan.md "Hard decisions".
    #expect(masHelperTimeoutSeconds == 600)
  }

  @Test func sentinelExitCodesAreNegative() {
    // mas itself only emits 0..255 — distinct sentinels avoid
    // collision with real exit codes.
    #expect(masHelperTimeoutExitCode < 0)
    #expect(masHelperInvalidInputExitCode < 0)
    #expect(masHelperTimeoutExitCode != masHelperInvalidInputExitCode)
  }

  @Test func toolPathIsAppleSiliconHomebrew() {
    // Helper runs as root with minimal PATH — no PATH lookup. Hard
    // path required.
    #expect(masHelperToolPath == "/opt/homebrew/bin/mas")
  }
}

struct MasInvocationResultTests {
  @Test func successDetectedByZeroExitCode() {
    let r = MasInvocationResult(exitCode: 0, stdout: "ok\n", stderr: "")
    #expect(r.didSucceed)
    #expect(!r.didTimeOut)
    #expect(!r.didReject)
  }

  @Test func timeoutDetected() {
    let r = MasInvocationResult(
      exitCode: masHelperTimeoutExitCode,
      stdout: "",
      stderr: "killed by SIGTERM after 600s"
    )
    #expect(!r.didSucceed)
    #expect(r.didTimeOut)
    #expect(!r.didReject)
  }

  @Test func rejectionDetected() {
    let r = MasInvocationResult(
      exitCode: masHelperInvalidInputExitCode,
      stdout: "",
      stderr: "invalid appStoreID 0"
    )
    #expect(!r.didSucceed)
    #expect(!r.didTimeOut)
    #expect(r.didReject)
  }

  @Test func nonZeroExitIsFailure() {
    let r = MasInvocationResult(exitCode: 1, stdout: "", stderr: "auth required")
    #expect(!r.didSucceed)
    #expect(!r.didTimeOut)
    #expect(!r.didReject)
  }
}

struct MasHelperClientErrorTests {
  @Test func errorDescriptionsAreInformative() {
    let e1 = MasHelperClientError.connectionFailed("xpc not running")
    #expect(e1.description.contains("xpc not running"))

    let e2 = MasHelperClientError.invalidProxyShape
    #expect(e2.description.contains("MasHelperProtocol"))

    let e3 = MasHelperClientError.invalidAppStoreID(0)
    #expect(e3.description.contains("0"))

    let e4 = MasHelperClientError.helperUnreachable("daemon not loaded")
    #expect(e4.description.contains("daemon not loaded"))
  }

  @Test func equalityRespectsAssociatedValues() {
    #expect(MasHelperClientError.invalidAppStoreID(0) == .invalidAppStoreID(0))
    #expect(MasHelperClientError.invalidAppStoreID(0) != .invalidAppStoreID(42))
    #expect(MasHelperClientError.invalidProxyShape == .invalidProxyShape)
    #expect(MasHelperClientError.connectionFailed("a") != .connectionFailed("b"))
  }
}

struct MasHelperClientInputValidationTests {
  @Test func installRejectsZeroAppStoreID() async throws {
    let client = MasHelperClient()
    do {
      _ = try await client.install(appStoreID: 0)
      Issue.record("expected throw on zero appStoreID")
    } catch let err as MasHelperClientError {
      #expect(err == .invalidAppStoreID(0))
    } catch {
      Issue.record("unexpected error type: \(error)")
    }
  }

  @Test func upgradeRejectsZeroInIDList() async throws {
    let client = MasHelperClient()
    do {
      _ = try await client.upgrade(appStoreIDs: [497799835, 0, 408981434])
      Issue.record("expected throw on zero in upgrade list")
    } catch let err as MasHelperClientError {
      #expect(err == .invalidAppStoreID(0))
    } catch {
      Issue.record("unexpected error type: \(error)")
    }
  }
}
