import Foundation

/// Loads the native AppKit helper bundle embedded in the app.
enum MacBridge {
    static let support: MacSupportProtocol? = {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("MacSupport.bundle"),
              let bundle = Bundle(url: url), bundle.load(),
              let type = bundle.principalClass as? MacSupportProtocol.Type else {
            log.error("could not load MacSupport.bundle")
            return nil
        }
        return type.init()
    }()
}
