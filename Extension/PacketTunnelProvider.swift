import Foundation
import Libbox
import NetworkExtension

/// Packet tunnel running the sing-box core. Written without async/await so it
/// runs on iOS 12. Platform glue is adapted from SagerNet/sing-box-for-apple (GPLv3).
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var service: LibboxBoxService?
    private var platform: TunnelPlatformInterface?

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
              let config = protocolConfiguration.providerConfiguration?["config"] as? String else {
            completionHandler(NSError(domain: "RufatVPN", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет конфигурации сервера"]))
            return
        }
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("box", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        LibboxSetup(base.path, base.path, base.path, false)

        // Start off the provider queue: openTun blocks while network settings are applied.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let platform = TunnelPlatformInterface(tunnel: self)
            self.platform = platform
            var error: NSError?
            guard let service = LibboxNewService(config, platform, &error) else {
                completionHandler(error ?? NSError(domain: "RufatVPN", code: 2))
                return
            }
            do {
                try service.start()
            } catch {
                completionHandler(error)
                return
            }
            self.service = service
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        try? service?.close()
        service = nil
        platform = nil
        completionHandler()
    }
}
