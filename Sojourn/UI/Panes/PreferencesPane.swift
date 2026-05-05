// Sojourn — PreferencesPane

import SwiftUI

struct PreferencesPane: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""

  private var filteredDomains: [PreferenceDomainEntry] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return store.preferenceDomains }
    return store.preferenceDomains.filter {
      $0.displayName.localizedCaseInsensitiveContains(trimmed)
        || $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        || $0.layer.localizedCaseInsensitiveContains(trimmed)
    }
  }

  var body: some View {
    let domains = filteredDomains

    VStack(alignment: .leading, spacing: 16) {
      header(domainCount: domains.count)

      if store.preferenceDomains.isEmpty {
        ContentUnavailableView(
          "No preference corpus loaded",
          systemImage: "slider.horizontal.3",
          description: Text("The bundled domain corpus could not be found in this build. Rebuild the app bundle, then refresh.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if domains.isEmpty {
        ContentUnavailableView.search(text: query)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(domains) { domain in
          domainRow(domain)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
      }
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
    .searchable(text: $query, placement: .toolbar, prompt: "Search domains")
    .accessibilityIdentifier("pane.preferences")
    .task {
      await store.refreshPreferenceDomains()
    }
  }

  private func header(domainCount: Int) -> some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Preferences")
          .font(.title2.weight(.semibold))
        Text("Bundled preference-domain corpus for defaults export/import.")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text("\(domainCount) domains")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func domainRow(_ domain: PreferenceDomainEntry) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol(for: domain))
        .foregroundStyle(domain.syncable ? Color.accentColor : Color.secondary)
        .frame(width: 22)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(domain.displayName)
          .font(.callout.weight(.semibold))
        Text(domain.bundleID)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
        Text(accessLabel(for: domain))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(layerLabel(for: domain))
          .font(.caption.weight(.medium))
        Text(domain.syncable ? "Syncable" : "Reference")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(domain.displayName). \(domain.bundleID). \(layerLabel(for: domain)). \(accessLabel(for: domain)). \(domain.syncable ? "Syncable" : "Reference")."
    )
  }

  private func symbol(for domain: PreferenceDomainEntry) -> String {
    switch domain.layer {
    case "sandboxed":      return "app.badge"
    case "system":         return "lock.shield"
    case "apple-internal": return "apple.logo"
    default:               return "gearshape"
    }
  }

  private func layerLabel(for domain: PreferenceDomainEntry) -> String {
    switch domain.layer {
    case "user":           return "User defaults"
    case "sandboxed":      return "Sandboxed plist"
    case "system":         return "System defaults"
    case "apple-internal": return "Apple internal"
    default:               return domain.layer
    }
  }

  private func accessLabel(for domain: PreferenceDomainEntry) -> String {
    switch domain.layer {
    case "sandboxed":
      return "Container preference path; Full Disk Access may be required"
    case "system", "apple-internal":
      return "System preference path; Full Disk Access may be required"
    default:
      return "User preference domain"
    }
  }
}
