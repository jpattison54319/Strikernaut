#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(dirname -- "$SCRIPT_DIR")}
PROJECT_ROOT="$REPO_ROOT"
PROJECT_FILE="$PROJECT_ROOT/GoalRush.xcodeproj"

fail() {
    echo "xcode-cloud: $*" >&2
    exit 1
}

cd "$PROJECT_ROOT"

action=${CI_XCODEBUILD_ACTION:-unknown}
scheme=${CI_XCODE_SCHEME:-GoalRush}
[ "$scheme" = "GoalRush" ] || fail "workflow must use the shared GoalRush scheme (got $scheme)"

if [ "$action" = "archive" ]; then
    settings=$(xcodebuild \
        -project "$PROJECT_FILE" \
        -scheme GoalRush \
        -configuration Release \
        -showBuildSettings 2>&1) || {
        echo "$settings" >&2
        fail "could not resolve Release build settings"
    }

    build_setting=$(printf '%s\n' "$settings" | awk -F ' = ' '$1 ~ /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')
    marketing_setting=$(printf '%s\n' "$settings" | awk -F ' = ' '$1 ~ /^[[:space:]]*MARKETING_VERSION[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')
    bundle_setting=$(printf '%s\n' "$settings" | awk -F ' = ' '$1 ~ /^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')

    [ "$build_setting" = "33" ] \
        || fail "archive Release settings resolve to build $build_setting, expected 33"
    [ "$marketing_setting" = "1.0" ] \
        || fail "archive Release settings resolve to version $marketing_setting, expected 1.0"
    [ "$bundle_setting" = "iCloud.org.xpetsllc.GoalRush" ] \
        || fail "archive Release settings resolve to bundle $bundle_setting"

    echo "xcode-cloud: archive preflight passed for Strikernaut 1.0 (33)"
else
    echo "xcode-cloud: $action preflight passed for scheme GoalRush"
fi
