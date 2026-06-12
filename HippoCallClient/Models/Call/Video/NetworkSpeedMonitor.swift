import UIKit
import Network

final class NetworkSpeedMonitor {

    static let shared = NetworkSpeedMonitor()

    var onUpdate: ((UIColor, String) -> Void)?

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.hippocall.networkMonitor", qos: .utility)
    private var pingTimer: Timer?
    private var isConnected = false

    // Apple's captive-portal check endpoint — tiny, always reachable, cache-busted each call.
    private let pingURL = URL(string: "http://captive.apple.com/hotspot-detect.html")!

    private init() {}

    // MARK: - Lifecycle

    func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.isConnected = path.status == .satisfied
            if !self.isConnected {
                DispatchQueue.main.async {
                    self.onUpdate?(UIColor.red, "No Network")
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)

        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
                self?.measureLatency()
            }
            self.pingTimer?.fire()
        }
    }

    func stop() {
        pathMonitor.cancel()
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Measurement

    private func measureLatency() {
        guard isConnected else { return }

        var request = URLRequest(url: pingURL)
        request.timeoutInterval = 4.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = Date()
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            let ms = Int(Date().timeIntervalSince(start) * 1000)

            let color: UIColor
            let label: String
            if error != nil || data == nil {
                color = UIColor.orange; label = "Weak"
            } else if ms < 150 {
                color = UIColor.green;  label = "\(ms) ms"
            } else if ms < 400 {
                color = UIColor.orange; label = "\(ms) ms"
            } else {
                color = UIColor.red;    label = "\(ms) ms"
            }

            DispatchQueue.main.async { self.onUpdate?(color, label) }
        }.resume()
    }
}
