cask "clicklight" do
  auto_updates true
  version "0.16.0"
  sha256 "92ad5cc4364acb74a47a13735b0747f4b06f64de883bea2a77cdf43b9622ea7b"

  url "https://github.com/aurorascharff/ClickLight/releases/download/v#{version}/ClickLight.zip"
  name "ClickLight"
  desc "Highlight clicks anywhere on your Mac for live demos"
  homepage "https://github.com/aurorascharff/ClickLight"

  app "ClickLight.app"

  postflight do
    system "xattr", "-cr", "#{appdir}/ClickLight.app"
  end

  zap trash: [
    "~/Library/Preferences/com.aurorascharff.ClickLight.plist",
  ]
end
