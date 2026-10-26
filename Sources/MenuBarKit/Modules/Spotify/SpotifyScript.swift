import Foundation

/// AppleScript bridge to Spotify. Callers must check Spotify is running first —
/// any `tell application` would otherwise launch it.
@MainActor
enum SpotifyScript {
    struct Status {
        var state: PlayState
        var track: Track
        var position: TimeInterval
    }

    enum Failure: Error {
        case notAuthorized
        case failed(String)
    }

    /// Fields joined with the ASCII unit separator. Times are whole milliseconds so
    /// the output never depends on the locale's decimal separator.
    private static let statusScript = NSAppleScript(source: """
        tell application id "com.spotify.client"
            set s to player state as text
            if s is "stopped" then return "stopped"
            set t to current track
            set art to ""
            try
                set art to artwork url of t
            end try
            set d to character id 31
            set pos to (player position * 1000) as integer
            return s & d & (name of t) & d & (artist of t) & d & (album of t) & d & ((duration of t) as text) & d & (pos as text) & d & (id of t) & d & art
        end tell
        """)

    /// Returns nil when Spotify is stopped (nothing loaded).
    static func fetchStatus() throws(Failure) -> Status? {
        guard let script = statusScript else { throw .failed("Could not create AppleScript") }
        let output = try execute(script).stringValue ?? ""
        let fields = output.components(separatedBy: "\u{1F}")
        guard fields.count >= 8, let state = PlayState(rawValue: fields[0]) else { return nil }
        let track = Track(
            id: fields[6],
            name: fields[1],
            artist: fields[2],
            album: fields[3],
            duration: (Double(fields[4]) ?? 0) / 1000,
            artworkURL: URL(string: fields[7])
        )
        return Status(state: state, track: track, position: (Double(fields[5]) ?? 0) / 1000)
    }

    static func send(_ command: String) {
        guard let script = NSAppleScript(source: "tell application id \"com.spotify.client\" to \(command)") else { return }
        _ = try? execute(script)
    }

    private static func execute(_ script: NSAppleScript) throws(Failure) -> NSAppleEventDescriptor {
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            // -1743: the user denied (or hasn't granted) Automation access to Spotify.
            if error[NSAppleScript.errorNumber] as? Int == -1743 { throw .notAuthorized }
            throw .failed(error[NSAppleScript.errorMessage] as? String ?? "AppleScript error")
        }
        return result
    }
}
