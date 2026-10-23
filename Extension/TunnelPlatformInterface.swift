import Foundation
import Libbox
import NetworkExtension

/// Implements the sing-box 1.8 platform interface for the packet tunnel.
/// Adapted from SagerNet/sing-box-for-apple (GPLv3), rewritten without async/await.
final class TunnelPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var tunnel: NEPacketTunnelProvider?

    init(tunnel: NEPacketTunnelProvider) {
        self.tunnel = tunnel
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options = options, let ret0_ = ret0_, let tunnel = tunnel else {
            throw NSError(domain: "RufatVPN", code: 10, userInfo: [NSLocalizedDescriptionKey: "openTun: invalid state"])
        }
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        if options.getAutoRoute() {
            settings.mtu = NSNumber(value: options.getMTU())
            var dnsError: NSError?
            let dnsServer = options.getDNSServerAddress(&dnsError)
            if let dnsError = dnsError {
                throw dnsError
            }
            settings.dnsSettings = NEDNSSettings(servers: [dnsServer])

            var addresses: [String] = []
            var masks: [String] = []
            if let iterator = options.getInet4Address() {
                while iterator.hasNext() {
                    guard let prefix = iterator.next() else { break }
                    addresses.append(prefix.address())
                    masks.append(prefix.mask())
                }
            }
            let ipv4 = NEIPv4Settings(addresses: addresses, subnetMasks: masks)
            ipv4.includedRoutes = [NEIPv4Route.default()]
            var excluded: [NEIPv4Route] = []
            if let iterator = options.getInet4RouteExcludeAddress() {
                while iterator.hasNext() {
                    guard let prefix = iterator.next() else { break }
                    excluded.append(NEIPv4Route(destinationAddress: prefix.address(), subnetMask: prefix.mask()))
                }
            }
            ipv4.excludedRoutes = excluded
            settings.ipv4Settings = ipv4
        }

        let semaphore = DispatchSemaphore(value: 0)
        var applyError: Error?
        tunnel.setTunnelNetworkSettings(settings) { error in
            applyError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let applyError = applyError {
            throw applyError
        }

        if let fd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }
        let fd = LibboxGetTunnelFileDescriptor()
        if fd == -1 {
            throw NSError(domain: "RufatVPN", code: 11, userInfo: [NSLocalizedDescriptionKey: "missing tun file descriptor"])
        }
        ret0_.pointee = fd
    }

    func usePlatformAutoDetectControl() -> Bool { true }
    func autoDetectControl(_ fd: Int32) throws {}
    func writeLog(_ message: String?) {
        if let message = message { NSLog("RufatVPN: %@", message) }
    }
    func useProcFS() -> Bool { false }
    func findConnectionOwner(_ ipProtocol: Int32, sourceAddress: String?, sourcePort: Int32, destinationAddress: String?, destinationPort: Int32, ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "RufatVPN", code: 12)
    }
    func packageName(byUid uid: Int32, error: NSErrorPointer) -> String { "" }
    func uid(byPackageName packageName: String?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "RufatVPN", code: 13)
    }
    func usePlatformDefaultInterfaceMonitor() -> Bool { false }
    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {}
    func useGetter() -> Bool { false }
    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        throw NSError(domain: "RufatVPN", code: 14)
    }
    func underNetworkExtension() -> Bool { true }
    func readWIFIState() -> LibboxWIFIState? { nil }
    func clearDNSCache() {}
}
