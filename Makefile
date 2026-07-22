DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR
DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5

.PHONY: generate build test test-ui verify

generate:
	xcodegen generate

build: generate
	xcodebuild -project GoalRush.xcodeproj -scheme GoalRush -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

test: generate
	xcodebuild test -project GoalRush.xcodeproj -scheme GoalRush -destination '$(DESTINATION)' -only-testing:GoalRushTests

test-ui: generate
	xcodebuild test -project GoalRush.xcodeproj -scheme GoalRush -destination '$(DESTINATION)' -only-testing:GoalRushUITests

verify: build test
