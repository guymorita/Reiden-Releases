#!/bin/bash

echo "Important: This script requires a .app file for Reiden to be present in the root directory where this script is run."
echo "Please ensure 'Reiden.app' is in the current directory before proceeding."
echo

# Prompt for version number
read -p "Enter the new version number (e.g., v0.4.1): " VERSION

# Validate input
if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format. Please use the format vX.Y.Z (e.g., v0.4.1)"
    exit 1
fi

# Set your variables
APP_NAME="Reiden"
APP_PATH="./$APP_NAME.app"
DMG_NAME="$APP_NAME-Installer.dmg"
ZIP_NAME="$APP_NAME.zip"
RELEASE_DIR="./releases/$VERSION"

# Create release directory
mkdir -p "$RELEASE_DIR"

# Sign the app (if not already signed)
echo "Signing the app..."
# Change 2: Use deep signing
codesign --force --options runtime --deep --sign "Developer ID Application: Guy Morita (9F9SXNU23N)" "$APP_PATH"

# Verify the app is properly signed
echo "Verifying app signature..."
codesign -dv --verbose=4 "$APP_PATH"

# Change 4: Additional verification before creating DMG
echo "Additional verification of app signature..."
codesign -dv --verbose=4 "$APP_PATH"

# Create DMG
echo "Creating DMG..."
create-dmg \
  --volname "$APP_NAME $VERSION" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 200 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 600 185 \
  "$RELEASE_DIR/$DMG_NAME" \
  "$APP_PATH"

# Sign the DMG
echo "Signing the DMG..."
codesign --force --sign "Developer ID Application: Guy Morita (9F9SXNU23N)" "$RELEASE_DIR/$DMG_NAME"

# Notarize the DMG
echo "Notarizing the DMG..."
notarization_output=$(xcrun notarytool submit "$RELEASE_DIR/$DMG_NAME" --wait --keychain-profile "AC_PASSWORD")
echo "$notarization_output"

# Extract submission ID (take only the first occurrence)
submission_id=$(echo "$notarization_output" | grep "id:" | head -n 1 | awk '{print $2}')

# Add more detailed notarization logging
if [ -n "$submission_id" ]; then
    echo "Fetching detailed notarization log for submission ID: $submission_id"
    xcrun notarytool log "$submission_id" --keychain-profile "AC_PASSWORD"
else
    echo "Failed to extract submission ID. Skipping detailed log fetch."
fi

# Staple the ticket to the DMG
echo "Stapling the ticket to the DMG..."
xcrun stapler staple "$RELEASE_DIR/$DMG_NAME"

# Verify the DMG
echo "Verifying DMG signature and notarization..."
spctl -a -vv -t open --context context:primary-signature "$RELEASE_DIR/$DMG_NAME"

# Create ZIP
echo "Creating ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$RELEASE_DIR/$ZIP_NAME"

echo "Process completed!"
echo "DMG created and notarized: $RELEASE_DIR/$DMG_NAME"
echo "ZIP created: $RELEASE_DIR/$ZIP_NAME"