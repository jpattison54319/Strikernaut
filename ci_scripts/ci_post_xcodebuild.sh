#!/bin/sh
set -eu

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
    exit 0
fi

# Xcode Cloud runs this hook even when xcodebuild fails. Preserve the original
# failure and only inspect a completed archive.
if [ "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]; then
    echo "xcode-cloud: archive failed; skipping bundle identity inspection"
    exit 0
fi

archive_path=${CI_ARCHIVE_PATH:-}
[ -n "$archive_path" ] || {
    echo "xcode-cloud: CI_ARCHIVE_PATH is missing after archive" >&2
    exit 1
}

app_path="$archive_path/Products/Applications/Strikernaut.app"
[ -d "$app_path" ] || {
    echo "xcode-cloud: Strikernaut.app is missing from $archive_path" >&2
    exit 1
}

info_plist="$app_path/Info.plist"
read_plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$info_plist"
}

marketing_version=$(read_plist_value CFBundleShortVersionString)
build_number=$(read_plist_value CFBundleVersion)
bundle_id=$(read_plist_value CFBundleIdentifier)
encryption_value=$(read_plist_value ITSAppUsesNonExemptEncryption)

[ "$marketing_version" = "1.0" ] \
    || { echo "xcode-cloud: archive version is $marketing_version, expected 1.0" >&2; exit 1; }
[ "$build_number" = "34" ] \
    || { echo "xcode-cloud: archive build is $build_number, expected 34" >&2; exit 1; }
[ "$bundle_id" = "iCloud.org.xpetsllc.GoalRush" ] \
    || { echo "xcode-cloud: archive bundle is $bundle_id" >&2; exit 1; }
[ "$encryption_value" = "false" ] \
    || { echo "xcode-cloud: archive export-compliance value is $encryption_value, expected false" >&2; exit 1; }

echo "xcode-cloud: archive verified Strikernaut 1.0 (34), $bundle_id"
