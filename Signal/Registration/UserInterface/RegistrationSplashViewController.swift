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

private final class ConcordSignInViewController: OWSViewController, UITextFieldDelegate {

    private struct LoginResponse: Decodable {
        let accountId: String
        let username: String
        let displayName: String
        let accessToken: String
    }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let usernameField = OWSTextField()
    private let passwordField = OWSTextField()
    private let statusLabel = UILabel.explanationLabelForRegistration(text: "")
    private let signInButton = UIButton(configuration: .largePrimary(title: "Sign in"))

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sign in"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .Signal.background

        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        scrollView.addSubview(contentView)
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])

        usernameField.font = .dynamicTypeBodyClamped
        usernameField.textColor = .Signal.label
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.spellCheckingType = .no
        usernameField.textContentType = .username
        usernameField.placeholder = "Username"
        usernameField.accessibilityIdentifier = "concord.signIn.username"
        usernameField.delegate = self
        usernameField.returnKeyType = .next

        passwordField.font = .dynamicTypeBodyClamped
        passwordField.textColor = .Signal.label
        passwordField.textContentType = .password
        passwordField.isSecureTextEntry = true
        passwordField.placeholder = "Password"
        passwordField.accessibilityIdentifier = "concord.signIn.password"
        passwordField.delegate = self
        passwordField.returnKeyType = .go

        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "concord.signIn.status"

        signInButton.addAction(UIAction { [weak self] _ in
            self?.signIn()
        }, for: .primaryActionTriggered)

        let brandMark = makeBrandMark()
        let titleLabel = UILabel.titleLabelForRegistration(text: "Welcome back")
        let explanationLabel = UILabel.explanationLabelForRegistration(
            text: "Sign in to Concord with your username and password.",
        )
        let privacyCard = makePrivacyCard()
        let usernameRow = makeInputRow(iconName: "person.fill", field: usernameField)
        let passwordRow = makeInputRow(iconName: "lock.fill", field: passwordField)
        let stack = UIStackView(arrangedSubviews: [
            brandMark,
            titleLabel,
            explanationLabel,
            privacyCard,
            usernameRow,
            passwordRow,
            signInButton,
            statusLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            usernameField.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            passwordField.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])

        let tapToDismissKeyboard = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapToDismissKeyboard.cancelsTouchesInView = false
        contentView.addGestureRecognizer(tapToDismissKeyboard)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func makeBrandMark() -> UIView {
        let container = UIView()
        let mark = UIView()
        mark.backgroundColor = .Signal.accent
        mark.layer.cornerRadius = 42
        let imageView = UIImageView(image: UIImage(systemName: "bubble.left.and.bubble.right.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        container.addSubview(mark)
        mark.addSubview(imageView)
        mark.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mark.topAnchor.constraint(equalTo: container.topAnchor),
            mark.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mark.widthAnchor.constraint(equalToConstant: 84),
            mark.heightAnchor.constraint(equalToConstant: 84),
            imageView.centerXAnchor.constraint(equalTo: mark.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: mark.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 38),
            imageView.heightAnchor.constraint(equalToConstant: 38),
        ])
        return container
    }

    private func makePrivacyCard() -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        iconView.tintColor = .Signal.accent
        iconView.contentMode = .scaleAspectFit
        let label = UILabel.explanationLabelForRegistration(
            text: "Phone-free sign-in. Account creation and SMS verification are unavailable in Concord.",
        )
        label.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        let card = UIView()
        card.backgroundColor = .Signal.secondaryBackground
        card.layer.cornerRadius = 16
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            stack.leadingAnchor.constraint(equalTo: card.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: card.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: card.layoutMarginsGuide.bottomAnchor),
        ])
        return card
    }

    private func makeInputRow(iconName: String, field: UITextField) -> UIView {
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = .Signal.accent
        iconView.contentMode = .scaleAspectFit
        let row = UIStackView(arrangedSubviews: [iconView, field])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        let container = UIView()
        container.backgroundColor = .Signal.secondaryBackground
        container.layer.cornerRadius = 14
        container.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            row.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
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

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc
    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardFrame = view.convert(endFrame, from: view.window)
        let keyboardOverlap = max(0, view.bounds.maxY - keyboardFrame.minY - view.safeAreaInsets.bottom)
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        UIView.animate(withDuration: animationDuration, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            self.scrollView.contentInset.bottom = keyboardOverlap + 24
            self.scrollView.verticalScrollIndicatorInsets.bottom = keyboardOverlap
            guard keyboardOverlap > 0 else { return }
            let signInRect = self.signInButton.convert(self.signInButton.bounds, to: self.scrollView)
            self.scrollView.scrollRectToVisible(signInRect.insetBy(dx: 0, dy: -16), animated: false)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === usernameField {
            passwordField.becomeFirstResponder()
        } else {
            dismissKeyboard()
            signIn()
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let fieldRect = textField.convert(textField.bounds, to: scrollView)
        scrollView.scrollRectToVisible(fieldRect.insetBy(dx: 0, dy: -24), animated: true)
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
