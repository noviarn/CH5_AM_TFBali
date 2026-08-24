import SwiftUI

struct PortraitLocked<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PortraitLockedHostingController<Content> {
        PortraitLockedHostingController(rootView: content)
    }

    func updateUIViewController(_ uiViewController: PortraitLockedHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}

final class PortraitLockedHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    override var shouldAutorotate: Bool { false }
}
