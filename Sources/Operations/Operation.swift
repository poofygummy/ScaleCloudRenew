//
//  Operation.swift
//  AltStore
//
//  Created by Riley Testut on 6/7/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public class ResultOperation<ResultType>: Operation
{
    public var resultHandler: ((Result<ResultType, Error>) -> Void)?

    // Should only be set by subclasses
    public var localizedFailure: String?

    @available(*, unavailable)
    public override func finish()
    {
        super.finish()
    }

    public func finish(_ result: Result<ResultType, Error>)
    {
        guard !self.isFinished else { return }

        var result = result

        if self.isCancelled
        {
            result = .failure(OperationError.cancelled)
        }
        else if case .failure(let nsError as NSError) = result, let localizedFailure, nsError.localizedFailure == nil {
            // Error doesn't have its own localizedFailure, so we give it the Operation's (if it exists)
            let error = nsError.withLocalizedFailure(localizedFailure)
            result = .failure(error)
        }
        
        // Diagnostics: perform verbose logging of the operations only if enabled (so as to not flood console logs)
        let isLoggingEnabledForThisOperation = OperationsLoggingControl.getFromDatabase(for: type(of: self))
        if UserDefaults.standard.isVerboseOperationsLoggingEnabled && isLoggingEnabledForThisOperation {
            // diagnostics logging
            let resultStatus = String(describing: result).prefix("success".count).uppercased()
            print("\n  ====> OPERATION: `\(type(of: self))` completed with: \(resultStatus) <====\n\n" +
                  "    Result: \(result)\n")
        }

        self.resultHandler?(result)

        super.finish()
    }
}

public class Operation: RSTOperation, ProgressReporting
{
    public let progress = Progress.discreteProgress(totalUnitCount: 1)
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier?
    
    public override var isAsynchronous: Bool {
        return true
    }
    
    public override init()
    {
        super.init()
        
        self.progress.cancellationHandler = { [weak self] in self?.cancel() }
    }
    
    public override func cancel()
    {
        super.cancel()
        
        if !self.progress.isCancelled
        {
            self.progress.cancel()
        }
    }
    
    public override func main()
    {
        super.main()
        
        let name = "com.altstore." + NSStringFromClass(type(of: self))
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            guard let backgroundTask = self?.backgroundTaskID else { return }
            
            self?.cancel()
            
            UIApplication.shared.endBackgroundTask(backgroundTask)
            self?.backgroundTaskID = .invalid
        }        
    }
    
    public override func finish()
    {
        guard !self.isFinished else { return }
        
        super.finish()
        
        if let backgroundTaskID = self.backgroundTaskID
        {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
    }
}
