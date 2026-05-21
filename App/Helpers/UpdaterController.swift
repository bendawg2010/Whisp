import AppKit
import Sparkle
import UserNotifications

final class UpdaterController: NSObject {
    private(set) lazy var controller: SPUStandardUpdaterController =
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

    private var autoDownloadInFlight = false

    override init() {
        super.init()
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    @objc func forceUpdateNow(_ sender: Any?) {
        NSLog("Whisp: forceUpdateNow clearing Sparkle and URL caches")
        let defaults = UserDefaults.standard
        for key in [
            "SUSkippedVersion",
            "SUSkippedMinorVersion",
            "SULastCheckTime",
            "SUFeedLastModifiedString",
            "SUFeedLastETagString",
            "SUUpdaterLastCheckTime",
            "SULastProfileSubmissionDate"
        ] {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        URLCache.shared.removeAllCachedResponses()
        controller.updater.resetUpdateCycle()
        runIndependentVersionCheck()
        controller.checkForUpdates(sender)
    }

    func runIndependentVersionCheck() {
        guard let url = URL(string: "https://whisp-buz.pages.dev/appcast.xml?t=\(Int(Date().timeIntervalSince1970))") else {
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self,
                  let data,
                  error == nil,
                  let xml = String(data: data, encoding: .utf8),
                  let latest = Self.latestVersion(from: xml) else {
                return
            }

            let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
            if latest.compare(current, options: .numeric) == .orderedDescending {
                DispatchQueue.main.async {
                    self.autoDownloadAndOpen(version: latest)
                }
            }
        }.resume()
    }

    func clearSkippedVersionsOnLaunch() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "SUSkippedVersion") != nil ||
            defaults.object(forKey: "SUSkippedMinorVersion") != nil {
            defaults.removeObject(forKey: "SUSkippedVersion")
            defaults.removeObject(forKey: "SUSkippedMinorVersion")
            defaults.synchronize()
        }
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    private func autoDownloadAndOpen(version: String) {
        if autoDownloadInFlight { return }
        autoDownloadInFlight = true

        let urlString = "https://github.com/bendawg2010/Whisp/releases/download/v\(version)/Whisp.dmg"
        guard let dmgURL = URL(string: urlString),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            autoDownloadInFlight = false
            return
        }

        let destination = downloads.appendingPathComponent("Whisp-v\(version).dmg")
        if FileManager.default.fileExists(atPath: destination.path) {
            NSWorkspace.shared.open(destination)
            notify(title: "Whisp \(version) ready", body: "Drag Whisp to Applications in the open window.")
            autoDownloadInFlight = false
            return
        }

        notify(title: "Downloading Whisp \(version)", body: "The installer will open when it finishes.")

        URLSession.shared.downloadTask(with: dmgURL) { [weak self] tempURL, _, error in
            defer { self?.autoDownloadInFlight = false }
            guard let self else { return }

            guard error == nil, let tempURL else {
                DispatchQueue.main.async {
                    self.notify(title: "Could not download Whisp \(version)", body: "Open the GitHub release from whisp-buz.pages.dev.")
                }
                return
            }

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(destination)
                    self.notify(title: "Whisp \(version) downloaded", body: "Drag Whisp to Applications to finish updating.")
                }
            } catch {
                NSLog("Whisp auto-download failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: "whisp.update.\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func latestVersion(from xml: String) -> String? {
        guard let range = xml.range(of: #"<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>"#, options: .regularExpression),
              let inner = xml[range].range(of: #">[^<]+<"#, options: .regularExpression) else {
            return nil
        }
        return String(xml[range][inner].dropFirst().dropLast())
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension UpdaterController: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        "https://whisp-buz.pages.dev/appcast.xml?t=\(Int(Date().timeIntervalSince1970))"
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        notify(title: "Whisp update available", body: "v\(item.versionString) is ready to install.")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        notify(title: "Installing Whisp v\(item.versionString)", body: "Whisp will relaunch in a moment.")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error {
            NSLog("Whisp Sparkle: \(error.localizedDescription)")
        }
    }
}
