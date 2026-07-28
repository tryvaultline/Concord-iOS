//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import SignalServiceKit
public import SignalUI

// MARK: - RegistrationSplashPresenter

public protocol RegistrationSplashPresenter: AnyObject {
    func continueFromSplash()
    func setHasOldDevice(_ hasOldDevice: Bool)
    func switchToDeviceLinkingMode()
}

// MARK: - RegistrationSplashViewController

public class RegistrationSplashViewController: OWSViewController, OWSNavigationChildController {

    public var prefersNavigationBarHidden: Bool {
        true
    }

    public init(presenter: RegistrationSplashPresenter) {
        super.init()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Signal.background

        let titleLabel = UILabel.titleLabelForRegistration(text: "Concord")
        let explanationLabel = UILabel.explanationLabelForRegistration(
            text: "Sign in with your Concord username. Phone numbers and verification codes are not used.",
        )
        let continueButton = UIButton(
            configuration: .largePrimary(title: "Sign in"),
            primaryAction: UIAction { [weak self] _ in
                self?.continuePressed()
            },
        )
        let largeButtonsContainer = UIStackView.verticalButtonStack(buttons: [continueButton])

        let stackView = addStaticContentStackView(arrangedSubviews: [
            titleLabel,
            explanationLabel,
            largeButtonsContainer,
        ])
        stackView.setCustomSpacing(24, after: titleLabel)
        stackView.setCustomSpacing(48, after: explanationLabel)
        view.sendSubviewToBack(stackView)
    }

    private func continuePressed() {
        Logger.info("")
        navigationController?.pushViewController(ConcordSignInViewController(), animated: true)
    }
}

private final class ConcordSignInViewController: OWSViewController {

    private struct LoginResponse: Decodable {
        let accountId: String
        let username: String
        let displayName: String
        let accessToken: String
    }

    private let usernameField = OWSTextField()
    private let passwordField = OWSTextField()
    private let statusLabel = UILabel.explanationLabelForRegistration(text: "")
    private let signInButton = UIButton(configuration: .largePrimary(title: "Sign in"))

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sign in"
        view.backgroundColor = .Signal.background

        usernameField.font = .dynamicTypeBodyClamped
        usernameField.textColor = .Signal.label
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.spellCheckingType = .no
        usernameField.textContentType = .username
        usernameField.placeholder = "Username"
        usernameField.accessibilityIdentifier = "concord.signIn.username"
        usernameField.borderStyle = .roundedRect

        passwordField.font = .dynamicTypeBodyClamped
        passwordField.textColor = .Signal.label
        passwordField.textContentType = .password
        passwordField.isSecureTextEntry = true
        passwordField.placeholder = "Password"
        passwordField.accessibilityIdentifier = "concord.signIn.password"
        passwordField.borderStyle = .roundedRect

        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "concord.signIn.status"

        signInButton.addAction(UIAction { [weak self] _ in
            self?.signIn()
        }, for: .primaryActionTriggered)

        let titleLabel = UILabel.titleLabelForRegistration(text: "Concord")
        let explanationLabel = UILabel.explanationLabelForRegistration(
            text: "Use one of the accounts created by your Concord administrator. Account creation, phone registration, SMS, and voice verification are disabled.",
        )
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            explanationLabel,
            usernameField,
            passwordField,
            signInButton,
            statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            usernameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            passwordField.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])
    }

    private func signIn() {
        guard let username = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordField.text,
              !username.isEmpty,
              !password.isEmpty else {
            showStatus("Enter your username and password.")
            return
        }
        guard let url = configuredLoginURL() else {
            showStatus("This build has no Concord authentication service configured. It will not use Signal registration services.")
            return
        }

        signInButton.isEnabled = false
        showStatus("Signing in…")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password,
        ])

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.signInButton.isEnabled = true
                guard error == nil,
                      let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let data,
                      let result = try? JSONDecoder().decode(LoginResponse.self, from: data) else {
                    self.showStatus("Unable to sign in. Check the username, password, and Concord service configuration.")
                    return
                }

                // The access token deliberately remains in memory until the protocol/device
                // provisioning flow is implemented. Do not place it in UserDefaults.
                _ = result.accountId
                _ = result.displayName
                _ = result.accessToken
                self.passwordField.text = nil
                self.showStatus("Signed in as \(result.username). Device and encrypted-message provisioning are not configured in this build yet.")
            }
        }.resume()
    }

    private func configuredLoginURL() -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "ConcordAuthBaseURL") as? String,
              let baseURL = URL(string: rawValue),
              let scheme = baseURL.scheme?.lowercased(),
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(baseURL.host?.lowercased())) else {
            return nil
        }
        return baseURL.appendingPathComponent("v1/accounts/login")
    }

    private func showStatus(_ text: String) {
        statusLabel.text = text
    }
}

// MARK: -

#if DEBUG
private class PreviewRegistrationSplashPresenter: RegistrationSplashPresenter {
    func continueFromSplash() {}
    func setHasOldDevice(_: Bool) {}
    func switchToDeviceLinkingMode() {}
}

@available(iOS 17, *)
#Preview {
    RegistrationSplashViewController(presenter: PreviewRegistrationSplashPresenter())
}
#endif
