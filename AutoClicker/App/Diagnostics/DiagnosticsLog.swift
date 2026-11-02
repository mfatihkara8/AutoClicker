#if DIAGNOSTICS
    import Foundation

    /// Progress lines for the scripts that launch a diagnostics run, written to standard error.
    enum DiagnosticsLog {
        static func write(_ message: String) {
            FileHandle.standardError.write(Data("[diagnostics] \(message)\n".utf8))
        }
    }
#endif
