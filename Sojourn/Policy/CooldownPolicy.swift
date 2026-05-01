// Sojourn — pure-function cooldown policy.
//
// Audit §3.1.2: extract cooldown decision logic out of `SyncCoordinator`
// and `CooldownGate` into a pure-function policy that's testable in
// isolation. Per `docs/reference/cooldown-policy.md`:
//
//   Tier A: 0 days  (Apple-blessed, system-managed — auto)
//   Tier B: 7 days  (curated repos — auto with cooldown)
//   Tier C: 7 days  (curated casks — auto with cooldown)
//   Tier D: 7 days  (npm/pip/gem — prompt with cooldown)
//   Tier E: 14 days (any/lifecycle-script-bearing — prompt, never silent)

import Foundation

internal enum CooldownPolicy {
  /// Cooldown duration per tier.
  internal static func cooldown(for tier: AutoUpdateTier) -> TimeInterval {
    switch tier {
    case .a: return 0
    case .b: return 7 * 24 * 60 * 60
    case .c: return 7 * 24 * 60 * 60
    case .d: return 7 * 24 * 60 * 60
    case .e: return 14 * 24 * 60 * 60
    }
  }

  /// Decide whether an update can apply right now.
  /// `lastUpdate`: timestamp of the previous successful install.
  /// `now`: current time (injectable for testing).
  /// `advisories`: matching advisories — high severity bypasses cooldown.
  internal static func canApply(
    tier: AutoUpdateTier,
    lastUpdate: Date?,
    now: Date = Date(),
    advisories: [AdvisoryReference] = []
  ) -> CooldownPolicyDecision {
    if let bypass = advisories.first(where: { $0.triggersBypass }) {
      return .allowAdvisoryBypass(bypass.id)
    }
    let window = cooldown(for: tier)
    guard let last = lastUpdate else {
      return .allowFirstInstall
    }
    let elapsed = now.timeIntervalSince(last)
    if elapsed >= window {
      return .allowAfterCooldown
    }
    return .blocked(remaining: window - elapsed, requiredTier: tier)
  }
}

internal enum CooldownPolicyDecision: Sendable, Equatable {
  case allowFirstInstall
  case allowAfterCooldown
  case allowAdvisoryBypass(String)
  case blocked(remaining: TimeInterval, requiredTier: AutoUpdateTier)

  internal var isAllowed: Bool {
    switch self {
    case .allowFirstInstall, .allowAfterCooldown, .allowAdvisoryBypass:
      return true
    case .blocked:
      return false
    }
  }
}
