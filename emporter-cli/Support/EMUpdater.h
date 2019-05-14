//
//  EMUpdater.h
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EMVersion.h"
#import "EMUpdate.h"

NS_ASSUME_NONNULL_BEGIN

/*! An object used to apply updates to the current process. */
@interface EMUpdater : NSObject

/*! The state of the updater */
typedef NS_ENUM(NSUInteger, EMUpdaterState) {
    
    /*! The update is downloading. This is only necessary for updates with non-filed based URLs. */
    EMUpdaterStateDownloading,
    
    /*! The update is being unpacked and its signature is being verified */
    EMUpdaterStateExtracting,
    
    /*! The update was canceled */
    EMUpdaterStateCanceled,
    
    /*! The update is complete, but not necessarily succesful. Check for errors. */
    EMUpdaterStateComplete
};

/*!
 Apply an update from a URL using a block-based handler to monitor state/progress and as a means of cancelation.
 
 Each state has its own progress value which can be used to track progress for the current step, or to cancel applying the update.
 
 Updates are downloaded only as needed. In other words, if the update has a file-based URL, the download step will be skipped.
 
 After extraction, the first binary matching the current process will be selected as the target. Before the replacement is made, its
 code signature will be verified. If the signature does not match, the update will not be applied and the task will be marked as complete
 with a non-nil error.
 
 Likewise, for any other errors, the updater will be marked as "complete" with a non-nil error.
 
 \param url             The URL used to apply an update
 \param stateHandler    The block to invoke (on a consistent background queue) for updates
 */
+ (void)applyWithURL:(NSURL *)url stateHandler:(void(^)(EMUpdaterState state, NSProgress *__nullable progress, NSError *__nullable error))stateHandler;

@end

NS_ASSUME_NONNULL_END
