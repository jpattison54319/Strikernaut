import GoogleMobileAds
import Observation
import UserMessagingPlatform

@MainActor
@Observable
final class RewardedAdService: NSObject, FullScreenContentDelegate {
    private(set) var isReady = false
    private(set) var isLoading = false
    private(set) var isPresenting = false
    private(set) var isPrivacyOptionsRequired = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private var rewardedAd: RewardedAd?
    @ObservationIgnored private var rewardHandler: (@MainActor @Sendable () -> Void)?
    @ObservationIgnored private var didBeginConfiguration = false
    @ObservationIgnored private var didStartMobileAds = false

    var isConfigured: Bool {
        AdMobConfiguration.rewardedAdUnitID != nil
            && !AdMobConfiguration.isDisabledForAutomation
    }

    func configure() {
        guard !didBeginConfiguration, isConfigured else { return }
        didBeginConfiguration = true

        if AdMobConfiguration.isRewardedAdStubEnabled {
            isReady = true
            return
        }

        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            Task { @MainActor in
                await self?.finishConsentGathering(requestError: error)
            }
        }
    }

    func loadAdIfNeeded() {
        guard isConfigured else { return }

        if AdMobConfiguration.isRewardedAdStubEnabled {
            isReady = true
            return
        }

        guard didStartMobileAds,
              !isReady,
              !isLoading,
              !isPresenting,
              let adUnitID = AdMobConfiguration.rewardedAdUnitID else {
            return
        }

        isLoading = true
        lastErrorMessage = nil
        Task {
            do {
                let ad = try await RewardedAd.load(with: adUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                rewardedAd = ad
                isReady = true
                isLoading = false
            } catch {
                rewardedAd = nil
                isReady = false
                isLoading = false
                lastErrorMessage = "A reward ad is not available right now."
            }
        }
    }

    @discardableResult
    func presentRewardedAd(
        onReward: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        guard isConfigured, !isPresenting else { return false }

        if AdMobConfiguration.isRewardedAdStubEnabled {
            isReady = false
            isPresenting = true
            Task {
                await Task.yield()
                onReward()
                isPresenting = false
                isReady = true
            }
            return true
        }

        guard let rewardedAd else {
            loadAdIfNeeded()
            return false
        }

        self.rewardedAd = nil
        rewardHandler = onReward
        isReady = false
        isPresenting = true
        rewardedAd.present(from: nil) { [weak self] in
            self?.deliverReward()
        }
        return true
    }

    func presentPrivacyOptions() async throws {
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        refreshPrivacyOptionsRequirement()
        startMobileAdsIfAllowed()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        rewardHandler = nil
        isPresenting = false
        lastErrorMessage = "The reward ad could not be shown. Please try again later."
        loadAdIfNeeded()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardHandler = nil
        isPresenting = false
        loadAdIfNeeded()
    }

    private func finishConsentGathering(requestError: Error?) async {
        refreshPrivacyOptionsRequirement()
        startMobileAdsIfAllowed()

        guard requestError == nil else {
            lastErrorMessage = "Ad privacy choices could not be refreshed."
            return
        }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            lastErrorMessage = "Ad privacy choices could not be displayed."
        }

        refreshPrivacyOptionsRequirement()
        startMobileAdsIfAllowed()
    }

    private func startMobileAdsIfAllowed() {
        guard ConsentInformation.shared.canRequestAds, !didStartMobileAds else { return }
        didStartMobileAds = true
        MobileAds.shared.start()
        loadAdIfNeeded()
    }

    private func refreshPrivacyOptionsRequirement() {
        isPrivacyOptionsRequired =
            ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func deliverReward() {
        let handler = rewardHandler
        rewardHandler = nil
        handler?()
    }
}
