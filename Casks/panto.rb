cask "panto" do
  version "0.6.0"
  sha256 "0a545d36f4f5b7374d916d0a85f855f41c0c57ceca34ed9a7bae5fa9ab9d94fa"

  url "https://github.com/AbayAtazhan/panto/releases/download/v#{version}/Panto.dmg"
  name "Panto"
  desc "Auto-zoom for screen recordings"
  homepage "https://github.com/AbayAtazhan/panto"

  depends_on macos: :sequoia

  app "Panto.app"

  caveats <<~EOS
    Panto is not notarized yet. If macOS blocks the first launch, run:
      xattr -dr com.apple.quarantine /Applications/Panto.app
    Or install with: brew install --cask --no-quarantine AbayAtazhan/panto/panto
  EOS

  zap trash: [
    "~/Movies/Panto",
    "~/Library/Preferences/app.panto.recorder.plist",
  ]
end
