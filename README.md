# HomeWidget

A macOS desktop widget that shows a regularly refreshed snapshot from one HomeKit camera. Add several widgets to show several cameras.

## How it works

- **App** (Mac Catalyst, because HomeKit is not available to native AppKit apps): finds your cameras, requests a still snapshot from each on a timer, and saves it as a JPEG in the shared App Group container.
- **Widget** (WidgetKit): reads that JPEG. Edit the widget to choose which camera it shows.

Widgets cannot talk to HomeKit or play video themselves, so the app has to be running for the widgets to update. HomeKit only draws snapshots into its own on-screen view, so the app screenshots its own window and crops out each camera.

The app lives in the menu bar (no Dock icon). Once a widget is set up, its window is parked behind the desktop wallpaper whenever the app isn't active: it has to stay on screen for HomeKit to keep answering and for the capture to work, but you never see it. Widgets do not refresh while the display is asleep or the screen is locked.

## Build

Requires Xcode 16.2 or later, macOS 15.2 or later, and an Apple ID signed in to Xcode (a free Personal Team works for local builds).

    brew install xcodegen
    cp Local.xcconfig.example Local.xcconfig   # then put your Team ID in it
    xcodegen
    open HomeWidget.xcodeproj

Run the `HomeWidget` scheme on "My Mac (Mac Catalyst)". Add a "HomeKit Camera" widget to the desktop, then right-click it and choose Edit to pick the camera and refresh interval.
