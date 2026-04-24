// Sojourn — CooldownGate
//
// Gates whether a package update can be auto-applied right now based on
// its ecosystem tier, the package's release age, and any active OSV
// advisory. See docs/ARCHITECTURE.md §7 and docs/SECURITY.md (Supply-chain
// cooldown).

import Foundation

internal struct CooldownDecision: Sendable, Hashable {
  internal let allowAuto: Bool
  internal let requiresPrompt: Bool
  internal let reason: String
  internal let advisoryBypass: Bool
}

internal struct OSVVulnerability: Sendable, Codable, Hashable {
  internal let id: String
  internal let modified: String?
}

internal struct OSVResponse: Sendable, Codable {
  internal let vulns: [OSVVulnerability]?
}

internal actor CooldownGate {
  internal typealias Fetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  private let settings: SettingsStore
  private let fetch: Fetcher
  private let now: @Sendable () -> Date

  internal init(
    settings: SettingsStore,
    fetch: @escaping Fetcher,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.settings = settings
    self.fetch = fetch
    self.now = now
  }

  internal static func live(settings: SettingsStore) -> CooldownGate {
    CooldownGate(
      settings: settings,
      fetch: { request in
        try await URLSession.shared.data(for: request)
      }
    )
  }

  internal func evaluate(
    package: String,
    manager: String,
    ecosystem: String? = nil,
    installedVersion: String?,
    candidateVersion: String?,
    releasedAt: Date?
  ) async -> CooldownDecision {
    let s = await settings.value
    guard s.cooldownEnabled else {
      return CooldownDecision(
        allowAuto: true, requiresPrompt: false,
        reason: "cooldown disabled in settings", advisoryBypass: false
      )
    }

    let tier = s.tier(for: manager)
    let age = releasedAt.map { now().timeIntervalSince($0) } ?? 0
    let ageDays = Int(age / 86400)

    var bypass = false
    if let ecosystem, let installedVersion {
      bypass = await osvHasAdvisory(
        ecosystem: ecosystem,
        package: package,
        version: installedVersion
      )
    }

    if bypass {
      return CooldownDecision(
        allowAuto: tier.canAutoSilent,
        requiresPrompt: tier.requiresUserPrompt,
        reason: "OSV advisory bypass",
        advisoryBypass: true
      )
    }

    if ageDays < tier.cooldownDays {
      return CooldownDecision(
        allowAuto: false,
        requiresPrompt: true,
        reason: "only \(ageDays)d old; tier \(tier.rawValue.uppercased()) cooldown is \(tier.cooldownDays)d",
        advisoryBypass: false
      )
    }

    return CooldownDecision(
      allowAuto: tier.canAutoSilent,
      requiresPrompt: tier.requiresUserPrompt,
      reason: "age \(ageDays)d ≥ tier \(tier.rawValue.uppercased()) cooldown \(tier.cooldownDays)d",
      advisoryBypass: false
    )
  }

  internal func osvHasAdvisory(
    ecosystem: String,
    package: String,
    version: String
  ) async -> Bool {
    let payload: [String: Any] = [
      "package": ["name": package, "ecosystem": ecosystem],
      "version": version,
    ]
    guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
      return false
    }
    var req = URLRequest(url: URL(string: "https://api.osv.dev/v1/query")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = body
    do {
      let (data, _) = try await fetch(req)
      let resp = try JSONDecoder().decode(OSVResponse.self, from: data)
      return (resp.vulns?.isEmpty == false)
    } catch {
      return false
    }
  }
}
