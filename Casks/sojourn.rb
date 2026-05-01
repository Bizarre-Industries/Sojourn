cask "sojourn" do
  version "0.2.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/Bizarre-Industries/Sojourn/releases/download/v#{version}/Sojourn.dmg",
      verified: "github.com/Bizarre-Industries/Sojourn/"
  name "Sojourn"
  desc "Brew-native Mac config manager"
  homepage "https://github.com/Bizarre-Industries/Sojourn"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :tahoe"
  depends_on formula: ["chezmoi", "mas"]

  app "Sojourn.app"

  uninstall quit:      "industries.bizarre.Sojourn",
            launchctl: "industries.bizarre.Sojourn.helper",
            delete:    [
              "/Library/LaunchDaemons/industries.bizarre.Sojourn.helper.plist",
              "/Library/PrivilegedHelperTools/industries.bizarre.Sojourn.helper",
            ]

  zap trash: [
    "~/Library/Application Support/Sojourn",
    "~/Library/Caches/Sojourn",
    "~/Library/Caches/industries.bizarre.Sojourn",
    "~/Library/Logs/Sojourn",
    "~/Library/Preferences/industries.bizarre.Sojourn.plist",
    "~/Library/Saved Application State/industries.bizarre.Sojourn.savedState",
  ]
end
