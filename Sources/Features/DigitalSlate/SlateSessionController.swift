import SwiftUI
import Observation

@MainActor
@Observable
public final class SlateSessionController {
    public let session: ProductionSession
    public var isPresented = false

    public init(session: ProductionSession) {
        self.session = session
    }

    public func present() {
        isPresented = true
    }

    public func dismiss() {
        isPresented = false
        session.slateIsRolling = false
    }

    public func toggleRolling() {
        session.slateIsRolling.toggle()
    }

    public func incrementTake() {
        session.slateTake += 1
    }

    public func bindings() -> (
        scene: Binding<String>,
        take: Binding<Int>,
        isRolling: Binding<Bool>
    ) {
        (
            scene: Binding(
                get: { self.session.slateScene },
                set: { self.session.slateScene = $0 }
            ),
            take: Binding(
                get: { self.session.slateTake },
                set: { self.session.slateTake = $0 }
            ),
            isRolling: Binding(
                get: { self.session.slateIsRolling },
                set: { self.session.slateIsRolling = $0 }
            )
        )
    }
}