#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
app=.build/PhoneVault.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"
cp .build/release/PhoneVault "$app/Contents/MacOS/"
cp -R .build/release/*.bundle "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>CFBundleExecutable</key><string>PhoneVault</string>
	<key>CFBundleIdentifier</key><string>com.phonevault.app</string>
	<key>CFBundleName</key><string>PhoneVault</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleLocalizations</key><array><string>en</string><string>pt-BR</string></array>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
EOF
echo "Built $app"
