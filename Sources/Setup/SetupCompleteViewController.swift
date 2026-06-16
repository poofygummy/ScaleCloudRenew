//
//  SetupCompleteViewController.swift
//  ScaleCloudRenew
//
//  Completion screen showing setup summary
//

import UIKit

class SetupCompleteViewController: SetupViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let checkmarkImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular)
        let image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Setup Complete!"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "ScaleCloud is now configured and ready to sign apps automatically."
        label.font = .systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let infoContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let certificateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Certificate Status"
        return label
    }()
    
    private let certificateValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let nextRefreshLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Next Automatic Refresh"
        return label
    }()
    
    private let nextRefreshValueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let reminderLabel: UILabel = {
        let label = UILabel()
        label.text = "Remember to trust the development certificate in Settings → General → VPN & Device Management after your first app installation."
        label.font = .systemFont(ofSize: 13)
        label.textColor = .systemOrange
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stepNumber = 5
        totalSteps = 5
        
        title = "Complete"
        
        setupUI()
        updateCertificateInfo()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        [checkmarkImageView, titleLabel, descriptionLabel, infoContainer, reminderLabel, doneButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        [certificateLabel, certificateValueLabel, nextRefreshLabel, nextRefreshValueLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            infoContainer.addSubview($0)
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
            
            // Checkmark
            checkmarkImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            checkmarkImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 80),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Info container
            infoContainer.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            infoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Certificate label
            certificateLabel.topAnchor.constraint(equalTo: infoContainer.topAnchor, constant: 16),
            certificateLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 16),
            certificateLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -16),
            
            // Certificate value
            certificateValueLabel.topAnchor.constraint(equalTo: certificateLabel.bottomAnchor, constant: 4),
            certificateValueLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 16),
            certificateValueLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -16),
            
            // Next refresh label
            nextRefreshLabel.topAnchor.constraint(equalTo: certificateValueLabel.bottomAnchor, constant: 16),
            nextRefreshLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 16),
            nextRefreshLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -16),
            
            // Next refresh value
            nextRefreshValueLabel.topAnchor.constraint(equalTo: nextRefreshLabel.bottomAnchor, constant: 4),
            nextRefreshValueLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 16),
            nextRefreshValueLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -16),
            nextRefreshValueLabel.bottomAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: -16),
            
            // Reminder
            reminderLabel.topAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: 24),
            reminderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            reminderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Done button
            doneButton.topAnchor.constraint(equalTo: reminderLabel.bottomAnchor, constant: 32),
            doneButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            doneButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
    }
    
    private func updateCertificateInfo() {
        // Check if we have certificate expiry info
        if let expiryDate = UserDefaults.standard.object(forKey: "com.scalecloud.cert.expiry") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            
            let calendar = Calendar.current
            let daysUntilExpiry = calendar.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
            
            certificateValueLabel.text = "Expires \(formatter.string(from: expiryDate)) (\(daysUntilExpiry) days)"
            
            // Calculate next refresh (3 days before expiry or tomorrow if already near expiry)
            let nextRefreshDate: Date
            if daysUntilExpiry > 4 {
                nextRefreshDate = calendar.date(byAdding: .day, value: -3, to: expiryDate) ?? Date()
            } else {
                nextRefreshDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            }
            
            nextRefreshValueLabel.text = formatter.string(from: nextRefreshDate)
        } else {
            // No certificate yet - will be generated on first signing
            certificateValueLabel.text = "Will be generated on first app refresh"
            
            // Next refresh in 3 days (default)
            let nextRefreshDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            nextRefreshValueLabel.text = formatter.string(from: nextRefreshDate)
        }
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        coordinator?.setupCompleted()
    }
}
