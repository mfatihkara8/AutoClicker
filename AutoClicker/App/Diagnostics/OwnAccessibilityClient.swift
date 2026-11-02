#if DIAGNOSTICS
    import ApplicationServices

    /// Presses the app's own controls through the Accessibility API, the way VoiceOver or a UI test would: buttons by
    /// their accessibility identifier, and the menu bar extra's button.
    ///
    /// Used only by the live check (`LiveCheckDriver`), which runs with the real Accessibility grant. Main-actor bound:
    /// a request to the app's own process is not sent through the system but answered right away on the calling
    /// thread, by AppKit and SwiftUI code that must run on the main thread (from another thread it traps).
    @MainActor
    enum OwnAccessibilityClient {
        enum Failure: Error, CustomStringConvertible {
            case notFound(String)
            case axError(String, AXError)

            var description: String {
                switch self {
                case .notFound(let what): "not found: \(what)"
                case .axError(let what, let error): "\(what) failed with AXError \(error.rawValue)"
                }
            }
        }

        /// Presses the first element whose `AXIdentifier` is `identifier`, searching every window of the app.
        static func pressElement(identifier: String) throws {
            let found = firstDescendant(of: application(), maxDepth: 40) {
                string($0, kAXIdentifierAttribute) == identifier
            }
            guard let element = found else {
                throw Failure.notFound("element with identifier \(identifier)")
            }
            try perform(kAXPressAction, on: element, what: "pressing \(identifier)")
        }

        /// Presses the menu bar extra, as a click on its icon does. Its menu's tracking loop runs inside this call, so
        /// it returns only once the menu has closed again.
        static func pressMenuBarExtra() throws {
            guard let bar = element(application(), kAXExtrasMenuBarAttribute) else {
                throw Failure.notFound("the app's extras menu bar (is the menu bar extra inserted?)")
            }
            guard let item = children(of: bar).first else {
                throw Failure.notFound("an item in the extras menu bar")
            }
            try perform(kAXPressAction, on: item, what: "pressing the menu bar extra")
        }

        // MARK: - Private

        private static func application() -> AXUIElement {
            AXUIElementCreateApplication(getpid())
        }

        private static func perform(_ action: String, on element: AXUIElement, what: String) throws {
            let error = AXUIElementPerformAction(element, action as CFString)
            guard error == .success else { throw Failure.axError(what, error) }
        }

        private static func firstDescendant(
            of root: AXUIElement, maxDepth: Int, where matches: (AXUIElement) -> Bool
        ) -> AXUIElement? {
            var pending: [(element: AXUIElement, depth: Int)] = [(root, 0)]
            var index = 0
            while index < pending.count {
                let (element, depth) = pending[index]
                index += 1
                if matches(element) {
                    return element
                }
                if depth < maxDepth {
                    pending.append(contentsOf: children(of: element).map { ($0, depth + 1) })
                }
            }
            return nil
        }

        private static func children(of element: AXUIElement) -> [AXUIElement] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else {
                return []
            }
            return value as? [AXUIElement] ?? []
        }

        private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value,
                CFGetTypeID(value) == AXUIElementGetTypeID()
            else {
                return nil
            }
            // The type ID was checked above. A conditional cast to a CoreFoundation type always succeeds, so it would
            // not check anything.
            return unsafeDowncast(value, to: AXUIElement.self)
        }

        private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
            return value as? String
        }
    }
#endif
