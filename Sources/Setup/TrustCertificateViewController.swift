//
//  TrustCertificateViewController.swift
//  ScaleCloudRenew
//
//  Guide user to trust development certificate in Settings
//

import UIKit

class TrustCertificateViewController: SetupViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Trust Development Certificate"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "After installing a development-signed app for the first time, you must trust the development certificate in Settings.\n\nWithout this step, the app will crash immediately on launch."
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let warningLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ The certificate will appear after the first app installation attempt. If you don't see it yet, that's normal - you can trust it after setup completes."
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemOrange
        label.numberOfLines = 0
        return label
    }()
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "To trust the certificate:"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        return label
    }()
    
    private let stepLabels: [UILabel] = {
        let steps = [
            "1. Tap \"Open Settings\" below",
            "2. Navigate to General",
            "3. Tap \"VPN & Device Management\"",
            "4. Under \"Developer App\", tap your Apple ID",
            "5. Tap \"Trust [Your Apple ID]\"",
            "6. Confirm by tapping \"Trust\" in the alert"
        ]
        return steps.map { text in
            let label = UILabel()
            label.text = text
            label.font = .systemFont(ofSize: 14)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            return label
        }
    }()
    
    private let openSettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open Settings", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private let confirmedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("I've Trusted It (or Will Later)", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stepNumber = 4
        totalSteps = 5
        
        title = "Trust Certificate"
        
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Add all components
        [titleLabel, descriptionLabel, warningLabel, instructionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        let stepsStack = UIStackView(arrangedSubviews: stepLabels)
        stepsStack.axis = .vertical
        stepsStack.spacing = 8
        stepsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepsStack)
        
        [openSettingsButton, confirmedButton].forEach {
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
            
            // Warning
            warningLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            warningLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            warningLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Instruction
            instructionLabel.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 24),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            // Steps
            stepsStack.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 12),
            stepsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stepsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Open Settings button
            openSettingsButton.topAnchor.constraint(equalTo: stepsStack.bottomAnchor, constant: 32),
            openSettingsButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            openSettingsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Confirmed button
            confirmedButton.topAnchor.constraint(equalTo: openSettingsButton.bottomAnchor, constant: 12),
            confirmedButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            confirmedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            confirmedButton.heightAnchor.constraint(equalToConstant: 50),
            confirmedButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        confirmedButton.addTarget(self, action: #selector(confirmedTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func openSettingsTapped() {
        // Try to open VPN & Device Management directly
        if let url = URL(string: "prefs:root=General&path=ManagedConfigurationList") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "App-prefs:General") {
            // Fallback to General settings
            UIApplication.shared.open(url)
        } else {
            // Last resort - open general Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    @objc private func confirmedTapped() {
        coordinator?.certificateTrustConfirmed()
    }
}
