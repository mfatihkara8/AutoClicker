/// One key press captured by a `ShortcutRecording`, before it is validated.
///
/// It carries everything needed to build a `Hotkey` without keeping the AppKit event alive.
struct RecordedKey: Equatable, Sendable {
    /// The virtual key code (`kVK_*`) of the pressed key.
    let keyCode: UInt32
    /// The Carbon modifier mask (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`) held during the press.
    let modifiers: UInt32
    /// What the key types on the current layout without modifiers, such as "k" or "ş", or `nil` when unknown.
    let characters: String?

    init(keyCode: UInt32, modifiers: UInt32 = 0, characters: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.characters = characters
    }
}
