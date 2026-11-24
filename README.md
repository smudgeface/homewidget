# HomeWidget

HomeKit camera snapshots on your Mac desktop, as widgets.

<!-- SCREENSHOT: docs/widgets.png — two or three camera widgets on the desktop -->

Each widget shows one camera and refreshes on its own schedule, from every 15 seconds to every 5 minutes. Add as many widgets as you have cameras. It works with any camera that appears in the Home app.

Apple's Home app has no camera widget for the Mac, and HomeKit does not let widgets show camera views directly. HomeWidget works around that with a small menu bar app that does the fetching.

## Status

HomeWidget is in early testing. It is free and open source, and for now you have to build it yourself with Xcode (about ten minutes, steps below).

**Want a version you can just download and install?** Packaging one means joining Apple's paid developer programme, so I'd like to know there's interest first. If you'd use it, add a 👍 to [this issue](https://github.com/smudgeface/homewidget/issues/1). A ready-made build would likely cost a couple of dollars on the App Store; building from source will stay free.

If HomeWidget is useful to you, you can [buy me a coffee](https://buymeacoffee.com/smudgeface).

## Using it

1. Launch HomeWidget and allow access to your home when asked. A camera icon appears in the menu bar; there is no Dock icon.
2. Right-click the desktop, choose Edit Widgets, and add a "HomeKit Camera" widget.
3. Right-click the widget and choose Edit to pick the camera and how often it refreshes.

Turn on "Open at Login" in the menu bar menu so the widgets keep working after a restart.

## Limitations

- **The app has to be running.** Widgets only display the last image the app saved.
- **No updates while the display is asleep or the screen is locked.** The widgets catch up within a few seconds of waking.
- **Stills, not video.** The fastest refresh is every 15 seconds.
- **Image quality is modest.** Fine for small and medium widgets, a little soft on the largest size.
- **Self-built copies expire.** With a free Apple ID, the build stops launching after 7 days and needs rebuilding in Xcode. A paid developer account extends that to a year.

## Build

Requires macOS 15.2 or later, Xcode 16.2 or later, and an Apple ID signed in to Xcode (a free one works).

    brew install xcodegen
    git clone https://github.com/smudgeface/homewidget.git
    cd homewidget
    cp Local.xcconfig.example Local.xcconfig

Put your Team ID in `Local.xcconfig`. You can find it in Xcode under Settings > Accounts, or by opening any project's Signing & Capabilities tab and choosing your team. Then:

    xcodegen
    open HomeWidget.xcodeproj

Run the `HomeWidget` scheme on "My Mac (Mac Catalyst)".

## How it works

HomeKit is not available to native Mac apps or to widgets, and it never hands an app the pixels of a camera snapshot: it only draws them into its own on-screen view. So HomeWidget is built in three parts.

- **App** (Mac Catalyst): finds your cameras, asks HomeKit for a still from each one that is on a widget, shows it in a window, then screenshots its own window and crops out each camera. The crops are saved as JPEGs in a container shared with the widget.
- **Widget** (WidgetKit): displays the saved JPEG for the camera you picked.
- **Mac helper** (AppKit bundle): provides the menu bar item and keeps the app's window out of sight.

The window has to stay on screen for HomeKit to keep answering and for the screenshot to work. When you switch to another app, HomeWidget parks it behind the desktop wallpaper, where it is still drawn but never seen.

Nothing leaves your Mac. The app talks only to HomeKit, and snapshots are stored only in the app's own container.

## Licence

[MIT](LICENSE)
