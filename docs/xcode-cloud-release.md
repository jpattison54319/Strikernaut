# Xcode Cloud release workflow

This repository checks in the generated `GoalRush.xcodeproj`. `project.yml` is
the source of truth for the app identity and release number; after changing it,
run `xcodegen generate` and commit both files.

The release identity for this workflow is:

- Product: `Strikernaut`
- Marketing version: `1.0`
- Build: `33`
- Bundle ID: `iCloud.org.xpetsllc.GoalRush`
- Project: `GoalRush.xcodeproj`
- Shared scheme: `GoalRush`

## App Store Connect workflow settings

Create or edit the workflow in App Store Connect under the app’s **Xcode Cloud >
Manage Workflows** page:

1. Use the branch containing the release commit (`ux-engagement-overhaul` for
   the current release branch), and start this release workflow manually.
2. Choose the latest released Xcode 26.x environment available to Xcode Cloud,
   not a beta environment. Enable **Clean** for this release archive.
3. Add one **Archive** action for iOS using the `GoalRush` scheme.
4. Set Deployment Preparation to **TestFlight and App Store**.
5. Do not enable a workflow option that rewrites the project’s version or build
   settings. The checked-in Release settings and the archive postflight both
   require build `33`.
6. After the archive succeeds, use the workflow’s App Store Connect/TestFlight
   distribution post-action if desired. Before submitting, verify that the
   uploaded build is exactly `1.0 (33)` and that the archive artifact has been
   retained.

The workflow’s first run must use a commit that includes `project.yml`, the
regenerated `GoalRush.xcodeproj`, and `ci_scripts/`. Xcode Cloud does not see
uncommitted local files.

## Cloud checks in this repository

- `ci_post_clone.sh` checks the shared scheme, bundle ID, marketing version,
  and generated build settings before an action starts.
- `ci_pre_xcodebuild.sh` checks the effective Release settings before archive.
- `ci_post_xcodebuild.sh` reads the actual archived app’s `Info.plist` and
  fails if the archive is not Strikernaut `1.0 (33)`, has the wrong bundle ID,
  or has unexpected export-compliance metadata.

These checks make the archive reproducible, but App Store Connect still owns
signing access, distribution, metadata, and the final **Submit for Review**
action.
