import Testing

@testable import AutoClicker

struct PositionOffsetEditorTests {
    @Test func readsTheStoredRadius() {
        #expect(PositionOffsetEditor(positionOffset: 20).points == 20)
    }

    @Test(arguments: [(-5, 0), (0, 0), (200, 200), (201, 200), (Int.max, 200)])
    func readsAClampedRadius(stored: Int, shown: Int) {
        #expect(PositionOffsetEditor(positionOffset: stored).points == shown)
    }

    @Test(arguments: [(-1, 0), (0, 0), (35, 35), (200, 200), (Int.max, 200), (Int.min, 0)])
    func setsAClampedRadius(input: Int, stored: Int) {
        var editor = PositionOffsetEditor(positionOffset: 10)
        editor.points = input
        #expect(editor.positionOffset == stored)
    }
}
