import Foundation
import NetworkExtension

/// Owns the single VPN profile in iOS settings and starts/stops it.
final class TunnelManager {
    static let extensionBundleId = (Bundle.main.bundleIdentifier ?? "com.rufat.vpn") + ".tunnel"

    private(set) var manager: NETunnelProviderManager?
    var onStatusChange: ((NEVPNStatus) -> Void)?

    init() {
        NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self, let status = self.manager?.connection.status else { return }
            self.onStatusChange?(status)
        }
    }

    var status: NEVPNStatus {
        return manager?.connection.status ?? .invalid
    }

    func load(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            DispatchQueue.main.async {
                self?.manager = managers?.first
                completion()
            }
        }
    }

    func connect(config: String, serverName: String, completion: @escaping (Error?) -> Void) {
        let manager = self.manager ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = TunnelManager.extensionBundleId
        proto.serverAddress = serverName
        proto.providerConfiguration = ["config": config]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "RufatVPN"
        manager.isEnabled = true

        manager.saveToPreferences { [weak self] error in
            if let error = error {
                DispatchQueue.main.async { completion(error) }
                return
            }
            // Reload is required after the first save, otherwise start fails.
            manager.loadFromPreferences { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error)
                        return
                    }
                    self?.manager = manager
                    do {
                        try manager.connection.startVPNTunnel()
                        completion(nil)
                    } catch {
                        completion(error)
                    }
                }
            }
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }
}
