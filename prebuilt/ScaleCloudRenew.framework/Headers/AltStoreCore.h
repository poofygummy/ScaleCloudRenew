//
//  AltStoreCore.h
//  AltStoreCore
//
//  Created by Riley Testut on 9/3/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for AltStoreCore.
FOUNDATION_EXPORT double AltStoreCoreVersionNumber;

//! Project version string for AltStoreCore.
FOUNDATION_EXPORT const unsigned char AltStoreCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <AltStoreCore/PublicHeader.h>

#import "Types/ALTAppPermissions.h"
#import "Types/ALTSourceUserInfoKey.h"
#import "Types/ALTPatreonBenefitID.h"

// Shared
#import "Shared/ALTConstants.h"
#import "Shared/Connections/ALTConnection.h"
#import "Shared/Errors/ALTWrappedError.h"
#import "Shared/Categories/NSError+ALTServerError.h"
#import "Shared/Categories/CFNotificationName+AltStore.h"
