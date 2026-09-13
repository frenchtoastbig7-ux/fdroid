#!/usr/bin/env bash
# Builds a signed Pocket Agent release, adds it to this F-Droid repo, signs the index, and publishes to GitHub Pages.
# Also attaches the APK to a GitHub Release on the source repo.
set -euo pipefail

APP_DIR="$HOME/claude/phone-agent"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ID="com.sovereignedge.pocketagent"
SOURCE_REPO="frenchtoastbig7-ux/pocket-agent"

export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
AAPT2="$ANDROID_HOME/build-tools/36.0.0/aapt2"

if [[ ! -f "$REPO_DIR/config.yml" ]]; then
  echo "Run 'fdroid init' in $REPO_DIR first (creates the repo signing key)." >&2
  exit 1
fi

(cd "$APP_DIR" && ./gradlew assembleRelease -Pminify -q)
APK="$APP_DIR/app/build/outputs/apk/release/app-release.apk"
if [[ ! -f "$APK" ]]; then
  echo "No signed release APK. Add the pocketagent.* signing properties to ~/.gradle/gradle.properties." >&2
  exit 1
fi

VERSION_NAME=$("$AAPT2" dump badging "$APK" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")
VERSION_CODE=$("$AAPT2" dump badging "$APK" | sed -n "s/.*versionCode='\([^']*\)'.*/\1/p")
TARGET="$REPO_DIR/repo/${APP_ID}_${VERSION_CODE}.apk"

if [[ -f "$TARGET" ]]; then
  echo "versionCode $VERSION_CODE is already published. Bump versionCode/versionName in app/build.gradle.kts." >&2
  exit 1
fi

mkdir -p "$REPO_DIR/repo"
cp "$APK" "$TARGET"
(cd "$REPO_DIR" && fdroid update)

(cd "$REPO_DIR" && git add -A && git commit -q -m "Pocket Agent $VERSION_NAME ($VERSION_CODE)" && git push -q origin main)

gh release create "v$VERSION_NAME" "$APK#pocket-agent-$VERSION_NAME.apk" \
  --repo "$SOURCE_REPO" --title "Pocket Agent $VERSION_NAME" \
  --notes "Signed release APK. Also available in the F-Droid repo: https://frenchtoastbig7-ux.github.io/fdroid/repo"

echo "Published Pocket Agent $VERSION_NAME ($VERSION_CODE)."
