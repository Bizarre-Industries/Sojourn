// BackendRegistryTests — smoke coverage for the actor that dispatches
// `PackageBackend` / `DotfileBackend` / `PrefBackend` / `SecretBroker`
// implementations. Audit §3.2.5.

import Foundation
import Testing
@testable import Sojourn

@Suite("BackendRegistry")
struct BackendRegistryTests {

  private struct StubPackageBackend: PackageBackend {
    let managerID: String
    func installed() async throws -> ManagerSnapshot {
      ManagerSnapshot(id: managerID, name: managerID)
    }
    func outdated() async throws -> [ManagedPackage] { [] }
    func install(_ packages: [String]) async throws -> [ManagedPackage] { [] }
    func remove(_ packages: [String]) async throws {}
    func upgrade(_ packages: [String]) async throws {}
    func search(_ query: String) async throws -> [ManagedPackage] { [] }
  }

  @Test("register + lookup by managerID")
  func registerAndLookup() async {
    let registry = BackendRegistry()
    await registry.register(StubPackageBackend(managerID: "brew"))
    await registry.register(StubPackageBackend(managerID: "npm"))
    let ids = await registry.allManagerIDs
    #expect(ids == ["brew", "npm"])
    let brew = await registry.package(for: "brew")
    #expect(brew?.managerID == "brew")
    let missing = await registry.package(for: "cargo")
    #expect(missing == nil)
  }

  @Test("installedAcrossAll fans out across registered backends")
  func fanOut() async {
    let registry = BackendRegistry()
    await registry.register(StubPackageBackend(managerID: "brew"))
    await registry.register(StubPackageBackend(managerID: "mas"))
    let snaps = await registry.installedAcrossAll()
    #expect(snaps.count == 2)
    #expect(snaps["brew"]?.id == "brew")
    #expect(snaps["mas"]?.id == "mas")
  }
}
