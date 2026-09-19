import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var packages: [Package] = []
    private(set) var hasAccess = false
    private(set) var isConfigured = false
    private(set) var isLoadingProducts = false
    private(set) var isBusy = false
    private(set) var notice: String?
    private(set) var errorMessage: String?
    private let entitlementID: String
    private let offeringID: String?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var annual: Package? { packages.first { $0.packageType == .annual } }
    var monthly: Package? { packages.first { $0.packageType == .monthly } }

    init() {
        let key = Self.setting("RevenueCatPublicSDKKey")
        entitlementID = Self.setting("RevenueCatEntitlementID").isEmpty ? "plus" : Self.setting("RevenueCatEntitlementID")
        let offering = Self.setting("RevenueCatOfferingID")
        offeringID = offering.isEmpty ? nil : offering
        guard !key.isEmpty else { return }
        let isTestStore = key.hasPrefix("test_")
        var appUserID: String?
        #if DEBUG
        Purchases.logLevel = .debug
        if isTestStore && ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            appUserID = ProcessInfo.processInfo.environment["REVENUECAT_TEST_USER_ID"]
        }
        #else
        guard !isTestStore else {
            errorMessage = "Subscriptions are unavailable in this build."
            return
        }
        #endif
        Purchases.configure(withAPIKey: key, appUserID: appUserID)
        isConfigured = true
        updatesTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.updateAccess(info)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        guard isConfigured else {
            notice = "Subscriptions are currently unavailable. Please try again later."
            return
        }
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        errorMessage = nil
        notice = nil
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering: Offering?
            if let offeringID {
                offering = offerings.offering(identifier: offeringID)
            } else {
                offering = offerings.current
            }
            guard let offering else {
                packages = []
                errorMessage = "Subscriptions are currently unavailable. Please try again later."
                await refreshEntitlements()
                return
            }
            packages = [offering.annual, offering.monthly].compactMap { $0 }.filter(Self.hasExpectedPeriod)
            if packages.isEmpty {
                errorMessage = "No subscription plans are available right now. Please try again later."
            }
        } catch {
            errorMessage = "Couldn’t load the plans: \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    func purchase(_ package: Package) async {
        guard isConfigured, !isBusy else { return }
        isBusy = true
        notice = nil
        errorMessage = nil
        defer { isBusy = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            updateAccess(result.customerInfo)
            if result.userCancelled {
                notice = "Purchase canceled. You can keep exploring."
            } else {
                notice = hasAccess
                    ? "Your Look Far Plus subscription is active."
                    : "Purchase received, but Plus access hasn’t been confirmed. Please try Restore purchases."
            }
        } catch {
            switch error as? RevenueCat.ErrorCode {
            case .purchaseCancelledError:
                notice = "Purchase canceled. You can keep exploring."
            case .paymentPendingError:
                notice = "Your purchase is awaiting approval. Access will update when it’s confirmed."
            default:
                errorMessage = "Couldn’t confirm the purchase: \(error.localizedDescription)"
            }
        }
    }

    func restore() async {
        guard isConfigured else {
            notice = "Purchases cannot be restored right now. Please try again later."
            return
        }
        guard !isBusy else { return }
        isBusy = true
        notice = nil
        errorMessage = nil
        defer { isBusy = false }
        do {
            updateAccess(try await Purchases.shared.restorePurchases())
            notice = hasAccess ? "Your subscription has been restored." : "No active Look Far Plus subscription was found."
        } catch {
            errorMessage = "Couldn’t restore purchases: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        guard isConfigured else { return }
        do { updateAccess(try await Purchases.shared.customerInfo()) }
        catch { errorMessage = "Couldn’t check subscription access: \(error.localizedDescription)" }
    }

    private func updateAccess(_ info: CustomerInfo) {
        let entitlement = info.entitlements[entitlementID]
        hasAccess = entitlement?.isActive == true
    }

    private static func setting(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasExpectedPeriod(_ package: Package) -> Bool {
        guard let period = package.storeProduct.subscriptionPeriod, period.value == 1 else { return false }
        return (package.packageType == .annual && period.unit == .year)
            || (package.packageType == .monthly && period.unit == .month)
    }
}
