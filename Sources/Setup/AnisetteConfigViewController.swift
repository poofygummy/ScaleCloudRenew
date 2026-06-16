//
//  AnisetteConfigViewController.swift
//  ScaleCloudRenew
//
//  Configure Anisette server URL (toth-adattar on Tailscale)
//

import UIKit

class AnisetteConfigViewController: SetupViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Configure Anisette Server"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "ScaleCloud requires an Anisette provisioning server to sign apps. This should be the Tailscale address of your toth-adattar server."
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "To find your server address, run this command on any Tailscale device:\n\ntailscale status | grep toth-adattar"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.backgroundColor = .systemGray6
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private let serverTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "http://100.x.y.z:6969"
        field.keyboardType = .URL
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.borderStyle = .roundedRect
        field.textContentType = .URL
        return field
    }()
    
    private let testButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Connection", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.isEnabled = false
        button.alpha = 0.5
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip (Signing will fail)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.setTitleColor(.systemRed, for: .normal)
        return button
    }()
    
    private var isServerValid = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stepNumber = 5
        totalSteps = 5
        
        title = "Anisette Server"
        
        setupUI()
        
        // Pre-fill if already configured
        if !UserDefaults.standard.menuAnisetteServersList.isEmpty {
            serverTextField.text = UserDefaults.standard.menuAnisetteServersList.first
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Add instructionLabel padding
        instructionLabel.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        
        [titleLabel, descriptionLabel, instructionLabel, serverTextField, testButton, statusLabel, continueButton, skipButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Instruction
            instructionLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Server field
            serverTextField.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 20),
            serverTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            serverTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            serverTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Test button
            testButton.topAnchor.constraint(equalTo: serverTextField.bottomAnchor, constant: 12),
            testButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            testButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            testButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: testButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 12),
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        testButton.addTarget(self, action: #selector(testConnectionTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func testConnectionTapped() {
        guard let urlString = serverTextField.text?.trimmingCharacters(in: .whitespaces),
              !urlString.isEmpty else {
            showStatus("Please enter a server URL", isError: true)
            return
        }
        
        guard let url = URL(string: urlString) else {
            showStatus("Invalid URL format", isError: true)
            return
        }
        
        dismissKeyboard()
        testButton.isEnabled = false
        testButton.setTitle("Testing...", for: .normal)
        statusLabel.isHidden = false
        statusLabel.text = "Connecting to server..."
        statusLabel.textColor = .secondaryLabel
        
        // Test connectivity using FetchAnisetteDataOperation.pingServer
        let operation = FetchAnisetteDataOperation(context: OperationContext())
        operation.pingServer(url) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                self?.testButton.setTitle("Test Connection", for: .normal)
                
                if success {
                    self?.showStatus("✓ Connection successful!", isError: false)
                    self?.isServerValid = true
                    self?.continueButton.isEnabled = true
                    self?.continueButton.alpha = 1.0
                } else {
                    let errorMsg = error?.localizedDescription ?? "Unknown error"
                    self?.showStatus("✗ Connection failed: \(errorMsg)", isError: true)
                    self?.isServerValid = false
                    self?.continueButton.isEnabled = false
                    self?.continueButton.alpha = 0.5
                }
            }
        }
    }
    
    @objc private func continueTapped() {
        guard isServerValid, let urlString = serverTextField.text?.trimmingCharacters(in: .whitespaces) else {
            return
        }
        
        coordinator?.anisetteConfigured(serverURL: urlString)
    }
    
    @objc private func skipTapped() {
        let alert = UIAlertController(
            title: "Skip Anisette Configuration?",
            message: "Without a working Anisette server, app signing will fail. You'll need to manually configure this later in Settings.\n\nAre you sure you want to skip?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Skip Anyway", style: .destructive) { [weak self] _ in
            self?.coordinator?.anisetteConfigured(serverURL: nil)
        })
        present(alert, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Helpers
    
    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.isHidden = false
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }
}
