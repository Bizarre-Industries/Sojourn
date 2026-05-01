cask "sojourn" do
  version "0.2.3"
  sha256 "327d4890e568d3151c30c29068d117959f0a15581f70bc18a14dd6974244bdf8"

  url "https://github.com/Bizarre-Industries/Sojourn/releases/download/v#{version}/Sojourn.dmg"
  name "Sojourn"
  desc "Brew-native config manager"
  homepage "https://github.com/Bizarre-Industries/Sojourn"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :tahoe"
  depends_on formula: ["chezmoi", "mas"]

  app "Sojourn.app"

  uninstall launchctl: "industries.bizarre.Sojourn.helper",
            quit:      "industries.bizarre.Sojourn",
            delete:    [
              "/Library/LaunchDaemons/industries.bizarre.Sojourn.helper.plist",
              "/Library/PrivilegedHelperTools/industries.bizarre.Sojourn.helper",
            ]

  zap trash: [
    "~/Library/Application Support/Sojourn",
    "~/Library/Caches/industries.bizarre.Sojourn",
    "~/Library/Caches/Sojourn",
    "~/Library/Logs/Sojourn",
    "~/Library/Preferences/industries.bizarre.Sojourn.plist",
    "~/Library/Saved Application State/industries.bizarre.Sojourn.savedState",
  ]

  caveats <<~EOS
    Sojourn shells out to chezmoi and mas. Both were installed as
    formula dependencies of this cask. To remove them when uninstalling
    Sojourn (cask uninstall doesn't cascade formula deps):

      brew uninstall chezmoi mas

    age and gitleaks ship bundled inside the .app — no formula install,
    no formula uninstall step.
  EOS
end
