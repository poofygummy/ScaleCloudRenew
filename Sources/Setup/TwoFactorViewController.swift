//
//  TwoFactorViewController.swift
//  ScaleCloudRenew
//
//  Presented whenever Apple requires a 2FA verification code during
//  AuthenticationOperation. The operation registers a one-shot
//  NotificationCenter observer for .twoFactorRequired, posts the notification
//  with a TwoFactorRequest, then blocks until the user submits or cancels.
//  No external setup call required.
//

import UIKit

// MARK: - Request object that bridges the async callback in AuthenticationOperation

/// Wraps the completion callback Apple's `verificationHandler` expects.
/// AuthenticationOperation creates one of these, posts it via notification,
/// then blocks waiting for `fulfill(code:)` to be called.
public final class TwoFactorRequest {
    private let handler: (String?) -> Void
    private var fulfilled = false

    init(handler: @escaping (String?) -> Void) {
        self.handler = handler
    }

    /// Call with the 6-digit code, or nil to cancel.
    func fulfill(code: String?) {
        guard !fulfilled else { return }
        fulfilled = true
        handler(code)
    }
}

// MARK: - Notification name

public extension Notification.Name {
    /// Posted by AuthenticationOperation when Apple demands a 2FA code.
    /// userInfo key "request" → TwoFactorRequest
    static let twoFactorRequired = Notification.Name("com.scalecloud.twoFactorRequired")
}

// MARK: - View Controller

/// Modal 6-digit code entry screen.
/// Present this when .twoFactorRequired fires; dismiss when request is fulfilled.
public class TwoFactorViewController: UIViewController {

    // Set by the presenter before showing
    var request: TwoFactorRequest?

    // MARK: UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Two-Factor Authentication"
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bodyLabel: UILabel = {
        let l = UILabel()
        l.text = "Enter the 6-digit verification code sent to your trusted Apple devices or phone number."
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let codeField: UITextField = {
        let f = UITextField()
        f.placeholder = "000000"
        f.keyboardType = .numberPad
        f.textAlignment = .center
        f.font = .monospacedDigitSystemFont(ofSize: 34, weight: .medium)
        f.borderStyle = .roundedRect
        f.autocorrectionType = .no
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    private let submitButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Continue"
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isEnabled = false
        return b
    }()

    private let cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Cancel"
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        isModalInPresentation = true // can't swipe away accidentally

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(codeField)
        view.addSubview(submitButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            bodyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            codeField.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 32),
            codeField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            codeField.widthAnchor.constraint(equalToConstant: 200),
            codeField.heightAnchor.constraint(equalToConstant: 56),

            submitButton.topAnchor.constraint(equalTo: codeField.bottomAnchor, constant: 24),
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            submitButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 8),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        codeField.addTarget(self, action: #selector(codeChanged), for: .editingChanged)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        codeField.becomeFirstResponder()
    }

    // MARK: Actions

    @objc private func codeChanged() {
        let text = codeField.text ?? ""
        // Enforce max 6 digits
        if text.count > 6 {
            codeField.text = String(text.prefix(6))
        }
        submitButton.isEnabled = (codeField.text?.count == 6)
    }

    @objc private func submitTapped() {
        let code = codeField.text ?? ""
        guard code.count == 6 else { return }
        request?.fulfill(code: code)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        request?.fulfill(code: nil)
        dismiss(animated: true)
    }
}


