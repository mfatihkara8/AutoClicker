#if DIAGNOSTICS
    import Foundation

    /// What a diagnostics launch does, chosen by an environment variable. Only built with the `DIAGNOSTICS`
    /// compilation condition, which Debug and `scripts/build-release.sh --profiling` set and the shipped build does not.
    enum DiagnosticsMode: Equatable {
        /// `AUTOCLICKER_SNAPSHOTS=<dir>`: drive the main window through a list of states, write one PNG per state and a
        /// layout report into the folder, then quit.
        case snapshots(directory: URL)
        /// `AUTOCLICKER_DRY_RUN=<seconds>`: idle for a few seconds, run a sequence for that many seconds without
        /// posting any event, idle again, then quit. For measuring CPU with `scripts/measure-performance.sh`.
        /// `AUTOCLICKER_DRY_RUN_DELAYS=<ms,ms,…>` sets one point per delay; the default is 3, 3 and 4 ms.
        case dryRun(seconds: Int, delays: [Int])
        /// `AUTOCLICKER_LIVE_CHECK=<frame file>`: an end-to-end check with real events against the click target of
        /// `scripts/live-check.sh`, whose window frames are in the file. It adds three sequence points with the real
        /// Add Point countdown, applies a profile from the menu bar extra, runs 12 real ⌘-clicks, writes
        /// `AUTOCLICKER_LIVE_CHECK_RESULT=<file>` (default: `live-check-result.json` next to the frame file) and quits.
        case liveCheck(frameFile: URL, resultFile: URL)
        /// `AUTOCLICKER_SHOWCASE=1`: stage sample profiles, a sequence and a filled counter for README screenshots, then
        /// stay open until the user quits.
        case showcase

        static let snapshotsVariable = "AUTOCLICKER_SNAPSHOTS"
        static let dryRunVariable = "AUTOCLICKER_DRY_RUN"
        static let dryRunDelaysVariable = "AUTOCLICKER_DRY_RUN_DELAYS"
        static let liveCheckVariable = "AUTOCLICKER_LIVE_CHECK"
        static let liveCheckResultVariable = "AUTOCLICKER_LIVE_CHECK_RESULT"
        static let showcaseVariable = "AUTOCLICKER_SHOWCASE"
        static let defaultDryRunDelays = [3, 3, 4]

        /// The mode the environment asks for, or `nil` for a normal launch. Snapshots win over a live check, which wins
        /// over a showcase, which wins over a dry run. A dry run with an unreadable or non-positive duration falls back to 30 seconds, and
        /// unreadable delays fall back to the default ones, rather than doing something unexpected.
        static func current(environment: [String: String]) -> DiagnosticsMode? {
            if let path = environment[snapshotsVariable], !path.isEmpty {
                let directory = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
                return .snapshots(directory: directory.standardizedFileURL)
            }
            if let path = environment[liveCheckVariable], !path.isEmpty {
                let frameFile = Self.fileURL(path)
                let resultFile = environment[liveCheckResultVariable].flatMap { $0.isEmpty ? nil : Self.fileURL($0) }
                return .liveCheck(
                    frameFile: frameFile,
                    resultFile: resultFile
                        ?? frameFile.deletingLastPathComponent().appendingPathComponent("live-check-result.json"))
            }
            if let value = environment[showcaseVariable], !value.isEmpty {
                return .showcase
            }
            if let value = environment[dryRunVariable] {
                let seconds = Int(value.trimmingCharacters(in: .whitespaces)) ?? 0
                let delays = (environment[dryRunDelaysVariable] ?? "")
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                let valid = !delays.isEmpty && delays.allSatisfy { ClickPoint.delayRange.contains($0) }
                return .dryRun(seconds: seconds > 0 ? seconds : 30, delays: valid ? delays : defaultDryRunDelays)
            }
            return nil
        }

        private static func fileURL(_ path: String) -> URL {
            URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        }
    }
#endif
