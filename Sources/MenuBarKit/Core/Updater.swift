import AppKit
import Observation

/// Checks GitHub for commits newer than the one this build came from, and updates
/// by running `make update` in the source checkout the app was built from.
@Observable @MainActor
final class Updater {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(commits: Int)
        case updating
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var lastChecked: Date? {
        didSet { UserDefaults.standard.set(lastChecked, forKey: "updater.lastChecked") }
    }

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    let commit = Bundle.main.object(forInfoDictionaryKey: "MBKCommit") as? String
    let branch = Bundle.main.object(forInfoDictionaryKey: "MBKBranch") as? String ?? "main"
    let repo = Bundle.main.object(forInfoDictionaryKey: "MBKRepo") as? String
    let sourceDir = Bundle.main.object(forInfoDictionaryKey: "MBKSourceDir") as? String

    static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MenuBarKit/update.log")

    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @ObservationIgnored private var timer: Timer?

    var isUpdateAvailable: Bool {
        if case .available = status { return true }
        return false
    }

    init() {
        lastChecked = UserDefaults.standard.object(forKey: "updater.lastChecked") as? Date
    }

    func start() {
        // Hourly wake-up; actually hits the network at most once a day.
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        Task {
            try? await Task.sleep(for: .seconds(10))
            checkIfDue()
        }
    }

    private func checkIfDue() {
        guard let lastChecked, Date().timeIntervalSince(lastChecked) < Self.checkInterval else {
            Task { await check() }
            return
        }
    }

    func check() async {
        guard let repo, let commit, commit != "unknown" else {
            status = .failed("This build has no source information.")
            return
        }
        status = .checking
        do {
            let url = URL(string: "https://api.github.com/repos/\(repo)/compare/\(commit)...\(branch)")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            lastChecked = Date()
            if code == 404 {
                // The built commit was never pushed — a local dev build.
                status = .upToDate
                return
            }
            guard code == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let aheadBy = json["ahead_by"] as? Int
            else {
                status = .failed("GitHub returned HTTP \(code).")
                return
            }
            status = aheadBy > 0 ? .available(commits: aheadBy) : .upToDate
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Runs `make update` detached; on success the Makefile quits and relaunches
    /// this app, so only failures come back here.
    func installUpdate() {
        guard let sourceDir else {
            status = .failed("Source folder unknown — run `make update` by hand.")
            return
        }
        status = .updating
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: Self.logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !fm.fileExists(atPath: Self.logURL.path) {
                fm.createFile(atPath: Self.logURL.path, contents: nil)
            }
            let log = try FileHandle(forWritingTo: Self.logURL)
            log.seekToEndOfFile()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "echo \"== $(date)\"; make -C \"$0\" update", sourceDir]
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = environment
            process.standardOutput = log
            process.standardError = log
            process.terminationHandler = { [weak self] process in
                guard process.terminationStatus != 0 else { return }
                Task { @MainActor in
                    self?.status = .failed("Update failed — see \(Self.logURL.path)")
                }
            }
            try process.run()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func revealLog() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.logURL])
    }
}
