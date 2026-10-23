import NetworkExtension
import UIKit

/// Minimal test screen: paste a vless:// or hysteria2:// link and connect.
final class MainViewController: UIViewController {
    private let tunnel = TunnelManager()
    private let linkField = UITextView()
    private let connectButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let serverLabel = UILabel()
    private static let linkKey = "rufatvpn.link"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
        setupViews()
        linkField.text = UserDefaults.standard.string(forKey: MainViewController.linkKey)
        tunnel.onStatusChange = { [weak self] status in self?.render(status) }
        tunnel.load { [weak self] in
            guard let self = self else { return }
            self.render(self.tunnel.status)
        }
    }

    private func setupViews() {
        let title = UILabel()
        title.text = "RufatVPN"
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.textColor = .white

        linkField.font = .systemFont(ofSize: 13)
        linkField.textColor = .white
        linkField.backgroundColor = UIColor(white: 1, alpha: 0.08)
        linkField.layer.cornerRadius = 12
        linkField.autocapitalizationType = .none
        linkField.autocorrectionType = .no
        linkField.accessibilityLabel = "Ссылка на сервер"

        let pasteButton = UIButton(type: .system)
        pasteButton.setTitle("Вставить из буфера", for: .normal)
        pasteButton.addTarget(self, action: #selector(pasteLink), for: .touchUpInside)

        connectButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 80
        connectButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)

        statusLabel.font = .systemFont(ofSize: 17, weight: .medium)
        statusLabel.textAlignment = .center
        serverLabel.font = .systemFont(ofSize: 14)
        serverLabel.textColor = UIColor(white: 1, alpha: 0.6)
        serverLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [title, linkField, pasteButton, connectButton, statusLabel, serverLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            linkField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            linkField.heightAnchor.constraint(equalToConstant: 90),
            connectButton.widthAnchor.constraint(equalToConstant: 160),
            connectButton.heightAnchor.constraint(equalToConstant: 160),
        ])
    }

    @objc private func pasteLink() {
        if let text = UIPasteboard.general.string {
            linkField.text = text
        }
    }

    @objc private func toggle() {
        switch tunnel.status {
        case .connected, .connecting, .reasserting:
            tunnel.disconnect()
            return
        default:
            break
        }
        let link = linkField.text ?? ""
        do {
            let server = try ConfigBuilder.parse(link)
            let config = try ConfigBuilder.config(for: server)
            UserDefaults.standard.set(link, forKey: MainViewController.linkKey)
            serverLabel.text = server.name
            tunnel.connect(config: config, serverName: server.name) { [weak self] error in
                if let error = error { self?.showError(error) }
            }
        } catch {
            showError(error)
        }
    }

    private func render(_ status: NEVPNStatus) {
        let style: (text: String, color: UIColor)
        switch status {
        case .connected: style = ("Подключено", UIColor(red: 0.2, green: 0.78, blue: 0.45, alpha: 1))
        case .connecting, .reasserting: style = ("Подключение…", UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1))
        case .disconnecting: style = ("Отключение…", UIColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1))
        default: style = ("Отключено", UIColor(red: 0.3, green: 0.4, blue: 0.95, alpha: 1))
        }
        statusLabel.text = style.text
        statusLabel.textColor = style.color
        connectButton.backgroundColor = style.color
        connectButton.setTitle(status == .connected ? "Стоп" : "Старт", for: .normal)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
