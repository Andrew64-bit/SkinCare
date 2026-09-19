import SkinCareKit
import SwiftUI

@main
struct SkinCareApp: App {
    private let environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let repository = environment.repository else { return }
            Task { _ = await repository.refreshIfNeeded() }
        }
    }
}

struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        #if DEBUG
        if let variant = ProcessInfo.processInfo.environment["SKINCARE_UITEST_LAB"] {
            AuditLabView(
                variant: variant,
                product: environment.repository?.catalog.products.first,
                products: environment.repository?.catalog.products ?? [],
                repository: environment.repository
            )
                .environment(environment.imageLoader)
        } else {
            mainView
        }
        #else
        mainView
        #endif
    }

    @ViewBuilder
    private var mainView: some View {
        if let repository = environment.repository {
            ProductListView(repository: repository)
                .environment(environment.imageLoader)
        } else {
            ContentUnavailableView(
                "Catalogo non disponibile",
                systemImage: "exclamationmark.triangle",
                description: Text(environment.loadError.map { String(describing: $0) } ?? "")
            )
        }
    }
}
