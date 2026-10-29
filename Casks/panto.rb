cask "panto" do
  version "0.3.0"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/USER/panto/releases/download/v#{version}/Panto.dmg"
  name "Panto"
  desc "Auto-zoom for screen recordings"
  homepage "https://github.com/USER/panto"

  depends_on macos: ">= :sequoia"

  app "Panto.app"

  caveats <<~EOS
    Panto is not notarized yet. If macOS blocks the first launch, run:
      xattr -dr com.apple.quarantine /Applications/Panto.app
    Or install with: brew install --cask --no-quarantine panto
  EOS

  zap trash: [
    "~/Movies/Panto",
    "~/Library/Preferences/app.panto.recorder.plist",
  ]
end
