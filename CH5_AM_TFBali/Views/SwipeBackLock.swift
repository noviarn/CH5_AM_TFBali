import SwiftUI

/// Disables the system edge-swipe-to-go-back gesture while `isLocked` — SwiftUI has no direct
/// API for this, so it reaches into the hosting `UINavigationController`'s
/// `interactivePopGestureRecognizer`, same UIKit-representable trick as `PortraitLocked`.
private struct SwipeBackLocker: UIViewControllerRepresentable {
    let isLocked: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = !isLocked
        }
    }
}

extension View {
    /// Locks both the swipe-back gesture and the back button while `isLocked` — use to keep a
    /// rider from navigating away mid-trip.
    func lockBackNavigation(_ isLocked: Bool) -> some View {
        background(SwipeBackLocker(isLocked: isLocked).frame(width: 0, height: 0))
            .navigationBarBackButtonHidden(isLocked)
    }
}
