//
//  ScaleCloudRenew.h
//  ScaleCloudRenew
//
//  Umbrella header exposing Objective-C to Swift within the framework
//

#import <Foundation/Foundation.h>

// Roxas - Generic
#import "RSTDefines.h"
#import "RSTConstants.h"
#import "RSTHelperFile.h"
#import "RSTError.h"

// Roxas - Operations
#import "RSTOperationQueue.h"
#import "RSTOperation.h"
#import "RSTOperation_Subclasses.h"
#import "RSTBlockOperation.h"
#import "RSTLoadOperation.h"

// Roxas - Core Data
#import "RSTPersistentContainer.h"
#import "RSTRelationshipPreservingMergePolicy.h"

// Roxas - Cell Content
#import "RSTCellContentCell.h"
#import "RSTCellContentView.h"
#import "RSTCellContentChange.h"
#import "RSTCellContentChangeOperation.h"
#import "RSTCellContentPrefetchingDataSource.h"
#import "RSTCellContentDataSource.h"
#import "RSTArrayDataSource.h"
#import "RSTFetchedResultsDataSource.h"
#import "RSTDynamicDataSource.h"
#import "RSTCompositeDataSource.h"
#import "RSTSearchController.h"
#import "RSTCollectionViewGridLayout.h"
#import "RSTCollectionViewCell.h"

// Roxas - Visual Components
#import "RSTPlaceholderView.h"
#import "RSTLaunchViewController.h"
#import "RSTSeparatorView.h"
#import "RSTNibView.h"
#import "RSTTintedImageView.h"
#import "RSTToastView.h"
#import "RSTNavigationController.h"

// Roxas - Functionality
#import "RSTHasher.h"

// Roxas - Categories
#import "UIImage+Manipulation.h"
#import "NSBundle+Extensions.h"
#import "NSFileManager+URLs.h"
#import "NSUserDefaults+DynamicProperties.h"
#import "UIViewController+TransitionState.h"
#import "UIView+AnimatedHide.h"
#import "NSString+Localization.h"
#import "NSPredicate+Search.h"
#import "UIAlertAction+Actions.h"
#import "NSLayoutConstraint+Edges.h"
#import "NSConstraintConflict+Conveniences.h"
#import "UISpringTimingParameters+Conveniences.h"
#import "RSTActivityIndicating.h"
#import "UIKit+ActivityIndicating.h"
#import "UITableView+CellContent.h"
#import "UITableViewCell+CellContent.h"
#import "UICollectionView+CellContent.h"
#import "UICollectionViewCell+CellContent.h"

// AltStoreCore
#import "ALTAppPermissions.h"
#import "ALTSourceUserInfoKey.h"
#import "ALTPatreonBenefitID.h"
#import "ALTConstants.h"
#import "ALTConnection.h"
#import "ALTWrappedError.h"
#import "NSError+ALTServerError.h"
#import "CFNotificationName+AltStore.h"

// AltSign headers are provided by AltSign.framework (ScaleCloudSign prebuilt)
