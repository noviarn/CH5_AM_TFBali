import SwiftUI

/// Pops a screen off the stack when a trip ends, so the rider lands back on the home page
/// rather than wherever they happened to start the trip from.
///
/// Every screen between home and the trip map has to carry this, or the stack stops unwinding
/// at the first one that doesn't — a trip started from a category page used to end back on
/// that category page.
///
/// `dismiss()` only acts on the topmost screen, so a view still covered by the trip map can't
/// dismiss itself when the broadcast lands. The intent is remembered instead and acted on in
/// `onAppear`, once the screens above have popped and this one is topmost again.
private struct ReturnHomeOnTripEnd: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var shouldReturnHome = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .tripEndedGoHome)) { _ in
                shouldReturnHome = true
                dismiss()
            }
            .onAppear {
                guard shouldReturnHome else { return }
                // Unanimated: this screen is only being passed through on the way home, and
                // animating each one in turn makes the stack visibly step back page by page
                // instead of landing on the home screen in one move. The trip map's own pop
                // keeps its animation — that is the one transition the rider asked for.
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { dismiss() }
            }
    }
}

extension View {
    func returnsHomeWhenTripEnds() -> some View {
        modifier(ReturnHomeOnTripEnd())
    }
}
