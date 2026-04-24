// Sojourn — GitHubDeviceAuth
//
// OAuth 2.0 Device Flow for GitHub. See docs/ARCHITECTURE.md §14 risk 7
// and docs/SECURITY.md ("Does not embed any API secret"). We use only a
// `client_id`; GitHub's device flow does not require a secret. The
// resulting access token is stored in the macOS Keychain.
//
// NOTE: `clientID` below is a placeholder — the maintainer must register a
// real OAuth App at https://github.com/settings/developers and paste the
// ID here before release. See MAINTAINERS.md.

import Foundation
import Security

internal enum GitHubAuthError: Error, Sendable {
  case networkFailure(String)
  case invalidResponse(String)
  case authorizationPending
  case slowDown
  case expiredToken
  case accessDenied
  case keychainFailure(OSStatus)
}

internal struct GitHubDeviceCode: Sendable, Codable, Hashable {
  internal let deviceCode: String
  internal let userCode: String
  internal let verificationURI: URL
  internal let expiresIn: Int
  internal let interval: Int

  internal enum CodingKeys: String, CodingKey {
    case deviceCode = "device_code"
    case userCode = "user_code"
    case verificationURI = "verification_uri"
    case expiresIn = "expires_in"
    case interval
  }
}

internal struct GitHubTokenResponse: Sendable, Codable {
  internal let accessToken: String?
  internal let tokenType: String?
  internal let scope: String?
  internal let error: String?
  internal let errorDescription: String?

  internal enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case scope
    case error
    case errorDescription = "error_description"
  }
}

internal actor GitHubDeviceAuth {
  internal static let clientID = "SOJOURN_OAUTH_CLIENT_ID_PLACEHOLDER"
  internal static let keychainService = "app.bizarre.sojourn"
  internal static let keychainAccount = "github-device"

  internal typealias Fetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  private let fetch: Fetcher
  private let clientID: String

  internal init(clientID: String = GitHubDeviceAuth.clientID, fetch: @escaping Fetcher) {
    self.clientID = clientID
    self.fetch = fetch
  }

  internal static func live() -> GitHubDeviceAuth {
    GitHubDeviceAuth(fetch: { request in
      try await URLSession.shared.data(for: request)
    })
  }

  // MARK: - Device flow

  internal func requestDeviceCode(scope: String = "repo") async throws -> GitHubDeviceCode {
    var req = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    req.httpBody = Self.formEncode(["client_id": clientID, "scope": scope])
    let (data, _) = try await fetch(req)
    do {
      return try JSONDecoder().decode(GitHubDeviceCode.self, from: data)
    } catch {
      throw GitHubAuthError.invalidResponse(String(decoding: data, as: UTF8.self))
    }
  }

  internal func pollForToken(deviceCode: GitHubDeviceCode) async throws -> String {
    var interval = TimeInterval(deviceCode.interval)
    let deadline = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))
    while Date() < deadline {
      try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
      do {
        return try await exchange(deviceCode: deviceCode)
      } catch GitHubAuthError.authorizationPending {
        continue
      } catch GitHubAuthError.slowDown {
        interval += 5
        continue
      }
    }
    throw GitHubAuthError.expiredToken
  }

  private func exchange(deviceCode: GitHubDeviceCode) async throws -> String {
    var req = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    req.httpBody = Self.formEncode([
      "client_id": clientID,
      "device_code": deviceCode.deviceCode,
      "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
    ])
    let (data, _) = try await fetch(req)
    let resp: GitHubTokenResponse
    do {
      resp = try JSONDecoder().decode(GitHubTokenResponse.self, from: data)
    } catch {
      throw GitHubAuthError.invalidResponse(String(decoding: data, as: UTF8.self))
    }
    if let token = resp.accessToken {
      return token
    }
    switch resp.error {
    case "authorization_pending": throw GitHubAuthError.authorizationPending
    case "slow_down": throw GitHubAuthError.slowDown
    case "expired_token": throw GitHubAuthError.expiredToken
    case "access_denied": throw GitHubAuthError.accessDenied
    default: throw GitHubAuthError.invalidResponse(resp.errorDescription ?? "?")
    }
  }

  // MARK: - Keychain

  internal func storeToken(_ token: String) throws {
    try Self.keychainStore(token: token)
  }

  internal func readToken() -> String? {
    Self.keychainRead()
  }

  internal func deleteToken() throws {
    try Self.keychainDelete()
  }

  private static func keychainStore(token: String) throws {
    let data = Data(token.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
    ]
    SecItemDelete(query as CFDictionary)
    var attrs = query
    attrs[kSecValueData as String] = data
    attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(attrs as CFDictionary, nil)
    if status != errSecSuccess {
      throw GitHubAuthError.keychainFailure(status)
    }
  }

  private static func keychainRead() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &out)
    guard status == errSecSuccess, let data = out as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func keychainDelete() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw GitHubAuthError.keychainFailure(status)
    }
  }

  private static func formEncode(_ params: [String: String]) -> Data {
    let pairs = params.map { key, value in
      let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
      let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
      return "\(k)=\(v)"
    }
    return Data(pairs.joined(separator: "&").utf8)
  }
}
