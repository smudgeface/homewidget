# HomeWidget

A macOS desktop widget that shows a regularly refreshed snapshot from one HomeKit camera. Add several widgets to show several cameras.

## How it works

- **App** (Mac Catalyst, because HomeKit is not available to native AppKit apps): finds your cameras, requests a still snapshot from each on a timer, and saves it as a JPEG in the shared App Group container.
- **Widget** (WidgetKit): reads that JPEG. Edit the widget to choose which camera it shows.

Widgets cannot talk to HomeKit or play video themselves, so the app has to be running, with its window open, for the widgets to update. HomeKit only draws snapshots into its own on-screen view, so the app screenshots its own window and crops out each camera.

## Build

Requires Xcode 16.2 or later, macOS 15.2 or later, and an Apple ID signed in to Xcode (a free Personal Team works for local builds).

    brew install xcodegen
    cp Local.xcconfig.example Local.xcconfig   # then put your Team ID in it
    xcodegen
    open HomeWidget.xcodeproj

Run the `HomeWidget` scheme on "My Mac (Mac Catalyst)". Add a "HomeKit Camera" widget to the desktop, then right-click it and choose Edit to pick the camera and refresh interval.
