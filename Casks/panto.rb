cask "panto" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/USER/panto/releases/download/v#{version}/Panto-#{version}.zip"
  name "Panto"
  desc "Auto-zoom for screen recordings"
  homepage "https://github.com/USER/panto"

  depends_on macos: ">= :sequoia"

  app "Panto.app"

  zap trash: [
    "~/Movies/Panto",
    "~/Library/Preferences/app.panto.recorder.plist",
  ]
end
