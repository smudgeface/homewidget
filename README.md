# HomeWidget

A macOS desktop widget that shows a regularly refreshed snapshot from one HomeKit camera. Add several widgets to show several cameras.

## How it works

- **App** (Mac Catalyst, because HomeKit is not available to native AppKit apps): finds your cameras, requests a still snapshot from each on a timer, and saves it as a JPEG in the shared App Group container.
- **Widget** (WidgetKit): reads that JPEG. Edit the widget to choose which camera it shows.

Widgets cannot talk to HomeKit or play video themselves, so the app has to be running, with its window open, for the widgets to update.

## Build

Requires Xcode 16 or later and an Apple Developer account (the HomeKit and App Group entitlements need a provisioning profile).

    brew install xcodegen
    xcodegen
    open HomeWidget.xcodeproj

Select your team under Signing & Capabilities for both targets, then run the `HomeWidget` scheme on "My Mac (Mac Catalyst)".
