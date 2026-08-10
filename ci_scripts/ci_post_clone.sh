#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=${CI_PRIMARY_REPOSITORY_PATH:-$(dirname -- "$SCRIPT_DIR")}
PROJECT_ROOT="$REPO_ROOT"
PROJECT_FILE="$PROJECT_ROOT/GoalRush.xcodeproj"
SCHEME_FILE="$PROJECT_FILE/xcshareddata/xcschemes/GoalRush.xcscheme"
PBXPROJ="$PROJECT_FILE/project.pbxproj"
PROJECT_YML="$PROJECT_ROOT/project.yml"

fail() {
    echo "xcode-cloud: $*" >&2
    exit 1
}

cd "$PROJECT_ROOT"

[ -d "$PROJECT_FILE" ] || fail "GoalRush.xcodeproj is missing"
[ -f "$SCHEME_FILE" ] || fail "shared GoalRush scheme is missing"
[ -f "$PBXPROJ" ] || fail "generated project.pbxproj is missing"
[ -f "$PROJECT_YML" ] || fail "project.yml is missing"

grep -Fq 'CURRENT_PROJECT_VERSION: "33"' "$PROJECT_YML" \
    || fail "project.yml is not pinned to release build 33"
grep -Fq 'MARKETING_VERSION: "1.0"' "$PROJECT_YML" \
    || fail "project.yml is not pinned to marketing version 1.0"
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER: iCloud.org.xpetsllc.GoalRush' "$PROJECT_YML" \
    || fail "project.yml has an unexpected app bundle identifier"

project_version_count=$(grep -cF 'CURRENT_PROJECT_VERSION = 33;' "$PBXPROJ" || true)
[ "$project_version_count" -eq 2 ] \
    || fail "generated project does not contain build 33 in both app configurations"
grep -Fq 'MARKETING_VERSION = 1.0;' "$PBXPROJ" \
    || fail "generated project is not pinned to marketing version 1.0"
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER = iCloud.org.xpetsllc.GoalRush;' "$PBXPROJ" \
    || fail "generated project has an unexpected app bundle identifier"

echo "xcode-cloud: checked out commit ${CI_COMMIT:-unknown}"
echo "xcode-cloud: project GoalRush.xcodeproj, scheme GoalRush"
echo "xcode-cloud: release identity Strikernaut 1.0 (33), iCloud.org.xpetsllc.GoalRush"
xcodebuild -version
