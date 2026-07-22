# Goal Rush

Goal Rush is a native portrait iPhone arcade game built with SwiftUI and
SpriteKit. Drag the player horizontally, automatically kick soccer balls into
approaching opponents, draft temporary techniques during a run, and spend
Training Tokens on permanent player and ball upgrades. Campaign spans the
Earth and Mars worlds; Endless mode stacks uncapped roguelite powers against
waves that keep scaling. World clears award permanent equippable gear.

## Requirements

- Xcode 26 or newer
- iOS 18 deployment target
- XcodeGen 2.45 or newer only when regenerating the project

The generated `GoalRush.xcodeproj` is checked in and opens directly in Xcode.

## Commands

```sh
make generate
make build
make test
make test-ui
make verify
```

The default test destination is iPhone 17 Pro on iOS 26.5. Change
`DESTINATION` in the Makefile if that simulator is not installed.

## Debug launch arguments

- `--reset-save`: clear local progression before launch
- `--reset-onboarding`: replay the first-time onboarding
- `--currency 500`: set starting tokens for the current launch
- `--screen endless`: open a menu screen directly (`levels`, `endless`, `gear`, `upgrades`, `settings`, `onboarding`, or `trophies`)
- `--level 6`: launch directly into a level
- `--endless mars`: launch an Endless run directly on an unlocked world
- `--unlock-worlds`: unlock both campaign worlds in debug builds
- `--unlock-gear`: earn every gear piece in debug builds
- `--fixed-seed 42`: reproduce wave and ability randomness
- `--show-draft`: open the temporary run-upgrade choice immediately after a direct level launch
- `--screen result-endless`: preview an Endless result (`result-world` previews a world-clear gear reveal)

Debug builds also expose token, level, and gear-unlock tools in Settings. Release
builds contain no analytics, advertisements, purchases, network calls, or
developer controls.
