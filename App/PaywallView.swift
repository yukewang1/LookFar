import SwiftUI
import RevenueCat

struct PaywallView: View {
    let subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan = Plan.annual
    @State private var policy: Policy?

    private enum Plan: String, CaseIterable, Identifiable {
        case annual, monthly
        var id: Self { self }
        var title: String { self == .annual ? "Yearly" : "Monthly" }
    }
    private enum Policy: String, Identifiable {
        case privacy = "Privacy", terms = "Terms"
        var id: Self { self }
    }

    private var selectedPackage: Package? { selectedPlan == .annual ? subscriptions.annual : subscriptions.monthly }
    private var savings: Int? {
        guard let annual = subscriptions.annual?.storeProduct, let monthly = subscriptions.monthly?.storeProduct,
              let currency = annual.currencyCode, currency == monthly.currencyCode,
              monthly.price > 0 else { return nil }
        let annualizedMonthly = monthly.price * 12
        let percentage = NSDecimalNumber(decimal: (1 - annual.price / annualizedMonthly) * 100).doubleValue
        let rounded = Int(percentage.rounded())
        return rounded > 0 ? rounded : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    if subscriptions.hasAccess {
                        Label("Look Far Plus is active", systemImage: "checkmark.seal")
                            .foregroundStyle(AppTheme.sage).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    } else {
                        planOptions
                    }
                    status
                    benefits
                    footer
                }
                .padding(24)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !subscriptions.hasAccess && selectedPackage != nil {
                    purchaseAction
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 12)
                        .background(AppTheme.background)
                        .overlay(alignment: .top) { Rectangle().fill(AppTheme.secondary.opacity(0.15)).frame(height: 1) }
                }
            }
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.cream)
            .navigationTitle("Look Far Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).tint(AppTheme.cream)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task { await loadPlans() }
            .sheet(item: $policy) { policy in policySheet(policy) }
        }
        .preferredColorScheme(.dark)
    }

    private func loadPlans() async {
        await subscriptions.loadProducts()
        if selectedPackage == nil {
            selectedPlan = subscriptions.annual != nil ? .annual : .monthly
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sun.horizon")
                    .font(.title2.weight(.ultraLight)).accessibilityHidden(true)
                Text("A LITTLE MORE SPACE").font(.caption2.weight(.semibold)).tracking(1.5)
            }
            .foregroundStyle(AppTheme.sage)
            Text("Make room for your eyes.")
                .font(AppTheme.title(34)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("A routine that fits", detail: "Classic, frequent, or longer rests.", symbol: "leaf")
            benefit("Your progress, gently", detail: "See your rests and consistency over time.", symbol: "chart.bar.xaxis")
            benefit("Always your choice", detail: "Rest, skip, or confirm a break you already took.", symbol: "hand.raised")
        }
    }

    private func benefit(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: symbol).foregroundStyle(AppTheme.sage).frame(width: 26, height: 25).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var planOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if subscriptions.isLoadingProducts {
                HStack(spacing: 10) {
                    SwiftUI.ProgressView().tint(AppTheme.sage)
                    Text("Loading plans…").font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
            }
            ForEach(Plan.allCases) { plan in
                if let package = plan == .annual ? subscriptions.annual : subscriptions.monthly {
                    planCard(plan, product: package.storeProduct)
                }
            }
            if let savings {
                Text("Yearly saves \(savings)% compared with 12 monthly payments.")
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    private func planCard(_ plan: Plan, product: StoreProduct) -> some View {
        let selected = selectedPlan == plan
        return Button { selectedPlan = plan } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3).foregroundStyle(selected ? AppTheme.sage : AppTheme.secondary)
                    .padding(.top, 4).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(plan.title).font(.headline).foregroundStyle(AppTheme.cream)
                        Spacer(minLength: 6)
                        if plan == .annual, savings != nil {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold)).tracking(0.7)
                                .foregroundStyle(AppTheme.background)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(AppTheme.sage, in: Capsule())
                        }
                    }
                    Text("\(product.localizedPriceString) / \(plan == .annual ? "year" : "month")")
                        .font(.title3.weight(.medium)).foregroundStyle(AppTheme.cream)
                        .accessibilityIdentifier("plan-price-\(plan.rawValue)")
                    Text(plan == .annual
                         ? product.localizedPricePerMonth.map { "Billed yearly · \($0)/month equivalent" } ?? "Billed yearly"
                         : "Billed monthly")
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AppTheme.surface : AppTheme.surface.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(selected ? AppTheme.sage : AppTheme.secondary.opacity(0.2), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-\(plan.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .disabled(subscriptions.isBusy)
    }

    @ViewBuilder
    private var purchaseAction: some View {
        if let package = selectedPackage {
            let product = package.storeProduct
            VStack(alignment: .leading, spacing: 12) {
                PrimaryButton(title: subscriptions.isBusy ? "Please wait…" : "Subscribe \(product.localizedPriceString) / \(selectedPlan == .annual ? "year" : "month")") {
                    Task { await subscriptions.purchase(package) }
                }
                .disabled(subscriptions.isBusy)
                .accessibilityIdentifier("subscribe")
                Text("Renews automatically at \(product.localizedPriceString) per \(selectedPlan == .annual ? "year" : "month") until canceled.")
                    .font(.footnote).foregroundStyle(AppTheme.secondary)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error = subscriptions.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(AppTheme.cream)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Purchase error. \(error)")
        }
        if let notice = subscriptions.notice {
            Text(notice).font(.subheadline).foregroundStyle(AppTheme.sage)
                .accessibilityLabel("Purchase status. \(notice)")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            if subscriptions.packages.isEmpty && !subscriptions.isLoadingProducts {
                Button("Try loading plans again") { Task { await loadPlans() } }
                    .font(.subheadline).tint(AppTheme.sage)
            }
            Button(subscriptions.isBusy ? "Please wait…" : "Restore purchases") {
                Task { await subscriptions.restore() }
            }
            .font(.subheadline).tint(AppTheme.sage).disabled(subscriptions.isBusy || !subscriptions.isConfigured)
            .accessibilityIdentifier("restorePurchases")
            Text("Payment is charged to your Apple Account when you confirm. Manage or cancel subscriptions in your Apple Account settings. Cancel at least 24 hours before renewal to avoid the next charge.")
                .font(.caption).foregroundStyle(AppTheme.secondary)
            HStack(spacing: 22) {
                Button("Privacy") { policy = .privacy }
                Button("Terms") { policy = .terms }
            }
            .font(.caption).tint(AppTheme.secondary)
        }
    }

    private func policySheet(_ policy: Policy) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(policy == .privacy ? "Your pauses stay personal." : "A little space, on your terms.")
                        .font(AppTheme.title(30))
                    if policy == .privacy {
                        Text("Look Far stores your routine, preferences, and break history locally on your device. Your rest history is not sent to RevenueCat. There are no ads.")
                        Text("RevenueCat receives an anonymous app user identifier, purchase information, and subscription status to manage access. Apple processes App Store payments; Look Far does not receive your payment card details.")
                        Link("RevenueCat privacy policy", destination: URL(string: "https://www.revenuecat.com/privacy/")!)
                            .tint(AppTheme.sage)
                        Text("Opening education links takes you to external websites with their own privacy policies.")
                        Text("You can clear local history in the app’s settings. Device backups may also contain app data, depending on your backup settings.")
                    } else {
                        Text("Look Far helps you build a break habit. Its timers and history are not medical measurements, diagnosis, or treatment. It does not claim to prevent myopia progression or retinal disease.")
                        Text("If you subscribe, the purchase confirmation shows the applicable price and billing period. Subscriptions renew until canceled through your Apple Account. Manage or cancel your subscription in your Apple Account settings.")
                    }
                }
                .font(.body).foregroundStyle(AppTheme.cream).lineSpacing(4)
                .padding(24)
            }
            .background(AppTheme.background)
            .navigationTitle(policy.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { self.policy = nil }.tint(AppTheme.sage) } }
        }
        .preferredColorScheme(.dark)
    }
}
