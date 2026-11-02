cask "panto" do
  version "0.5.2"
  sha256 "a628be6b61563585e4f8bc16add3826a3cef99f8818a2d24979f6a5e86b72f30"

  url "https://github.com/AbayAtazhan/panto/releases/download/v#{version}/Panto.dmg"
  name "Panto"
  desc "Auto-zoom for screen recordings"
  homepage "https://github.com/AbayAtazhan/panto"

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
