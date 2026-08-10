import Foundation

enum AdMobConfiguration {
    static let rewardedTestAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    static var isRewardedAdStubEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--rewarded-ad-stub")
#else
        false
#endif
    }

    static var rewardedAdUnitID: String? {
        if isRewardedAdStubEnabled {
            return rewardedTestAdUnitID
        }

#if DEBUG
        if !ProcessInfo.processInfo.arguments.contains("--use-production-rewarded-ads") {
            return rewardedTestAdUnitID
        }
#endif

        guard let identifier = Bundle.main.object(
            forInfoDictionaryKey: "GADRewardedAdUnitIdentifier"
        ) as? String,
            identifier.hasPrefix("ca-app-pub-"),
            identifier.contains("/")
        else {
            return nil
        }
        return identifier
    }

    static var isDisabledForAutomation: Bool {
#if DEBUG
        guard !isRewardedAdStubEnabled else { return false }
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--disable-ads")
            || arguments.contains("--reset-save")
            || arguments.contains("--reset-onboarding")
            || arguments.contains("--screen")
            || arguments.contains("--level")
            || arguments.contains("--endless")
#else
        false
#endif
    }
}
