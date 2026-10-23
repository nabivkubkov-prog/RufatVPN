import Foundation

/// Converts share links (vless://, hysteria2://, hy2://) into a sing-box 1.8 config.
enum ConfigBuilder {
    enum BuildError: LocalizedError {
        case unsupportedScheme
        case invalidLink

        var errorDescription: String? {
            switch self {
            case .unsupportedScheme: return "Поддерживаются ссылки vless:// и hysteria2://"
            case .invalidLink: return "Не удалось разобрать ссылку"
            }
        }
    }

    struct Server {
        let name: String
        let outbound: [String: Any]
    }

    static func parse(_ link: String) throws -> Server {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty,
              let port = components.port else {
            throw BuildError.invalidLink
        }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            query[item.name.lowercased()] = item.value ?? ""
        }
        let name = components.fragment?.removingPercentEncoding ?? host
        let user = components.user?.removingPercentEncoding ?? ""

        switch scheme {
        case "vless":
            guard !user.isEmpty else { throw BuildError.invalidLink }
            return Server(name: name, outbound: vless(host: host, port: port, uuid: user, query: query))
        case "hysteria2", "hy2":
            let password = components.password.map { "\(user):\($0)" } ?? user
            guard !password.isEmpty else { throw BuildError.invalidLink }
            return Server(name: name, outbound: hysteria2(host: host, port: port, password: password, query: query))
        default:
            throw BuildError.unsupportedScheme
        }
    }

    private static func vless(host: String, port: Int, uuid: String, query: [String: String]) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "vless",
            "tag": "proxy",
            "server": host,
            "server_port": port,
            "uuid": uuid,
        ]
        if let flow = query["flow"], !flow.isEmpty {
            outbound["flow"] = flow
        }
        let security = query["security"] ?? "none"
        if security == "tls" || security == "reality" {
            var tls: [String: Any] = [
                "enabled": true,
                "server_name": query["sni"].flatMap { $0.isEmpty ? nil : $0 } ?? host,
                "utls": ["enabled": true, "fingerprint": query["fp"].flatMap { $0.isEmpty ? nil : $0 } ?? "chrome"],
            ]
            if let alpn = query["alpn"], !alpn.isEmpty {
                tls["alpn"] = alpn.split(separator: ",").map(String.init)
            }
            if security == "reality" {
                tls["reality"] = [
                    "enabled": true,
                    "public_key": query["pbk"] ?? "",
                    "short_id": query["sid"] ?? "",
                ]
            }
            outbound["tls"] = tls
        }
        switch query["type"] ?? "tcp" {
        case "ws":
            var transport: [String: Any] = ["type": "ws", "path": query["path"]?.removingPercentEncoding ?? "/"]
            if let hostHeader = query["host"], !hostHeader.isEmpty {
                transport["headers"] = ["Host": hostHeader]
            }
            outbound["transport"] = transport
        case "grpc":
            outbound["transport"] = ["type": "grpc", "service_name": query["servicename"] ?? ""]
        case "http", "h2":
            outbound["transport"] = ["type": "http", "path": query["path"]?.removingPercentEncoding ?? "/"]
        default:
            break
        }
        return outbound
    }

    private static func hysteria2(host: String, port: Int, password: String, query: [String: String]) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "hysteria2",
            "tag": "proxy",
            "server": host,
            "server_port": port,
            "password": password,
            "tls": [
                "enabled": true,
                "server_name": query["sni"].flatMap { $0.isEmpty ? nil : $0 } ?? host,
                "insecure": query["insecure"] == "1",
                "alpn": ["h3"],
            ],
        ]
        if let obfs = query["obfs"], obfs == "salamander" {
            outbound["obfs"] = ["type": "salamander", "password": query["obfs-password"] ?? ""]
        }
        return outbound
    }

    /// Full config: TUN inbound with auto route, everything through the proxy,
    /// DNS over the tunnel. Kept minimal to fit the iOS 12 extension memory limit.
    static func config(for server: Server) throws -> String {
        let config: [String: Any] = [
            "log": ["level": "warn"],
            "dns": [
                "servers": [
                    ["tag": "remote", "address": "tls://1.1.1.1", "detour": "proxy"],
                    ["tag": "local", "address": "local", "detour": "direct"],
                ],
                "rules": [["outbound": "any", "server": "local"]],
                "final": "remote",
                "strategy": "ipv4_only",
            ],
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "inet4_address": "172.19.0.1/30",
                "mtu": 1500,
                "auto_route": true,
                "stack": "gvisor",
                "sniff": true,
            ]],
            "outbounds": [
                server.outbound,
                ["type": "direct", "tag": "direct"],
                ["type": "dns", "tag": "dns-out"],
            ],
            "route": [
                "rules": [["protocol": "dns", "outbound": "dns-out"]],
                "final": "proxy",
                "auto_detect_interface": true,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
