import Foundation

/// The interface between the Catalyst app and its native AppKit helper bundle.
/// Compiled into both; they find each other through the shared Objective-C name.
@objc(MacSupportProtocol)
protocol MacSupportProtocol: NSObjectProtocol {
    init()
    /// Installs the menu bar item and starts showing the window while the app is
    /// active and hiding it otherwise. `shouldHide` says whether hiding is allowed yet.
    func start(shouldHide: @escaping () -> Bool)
    /// Hides the window now if the app isn't the active one.
    func hideIfInactive()
}
