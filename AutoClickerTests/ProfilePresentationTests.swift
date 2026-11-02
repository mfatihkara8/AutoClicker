import Testing

@testable import AutoClicker

struct ProfilePresentationTests {
    @Test func statusNamesTheActiveProfile() {
        #expect(ProfilePresentation(name: "Work", isModified: false).statusText == "Profile: Work")
    }

    @Test func statusMarksAModifiedProfile() {
        #expect(ProfilePresentation(name: "Work", isModified: true).statusText == "Profile: Work (modified)")
    }

    @Test func saveChangesTitleQuotesTheName() {
        #expect(ProfilePresentation(name: "Work", isModified: true).saveChangesTitle == "Save Changes to “Work”")
    }

    @Test func everyNameRejectionHasText() {
        let rejections: [Profile.NameRejection] = [.empty, .duplicate, .tooManyProfiles]
        #expect(rejections.allSatisfy { !$0.displayText.isEmpty })
        #expect(Profile.NameRejection.tooManyProfiles.displayText.contains("50"))
    }
}
