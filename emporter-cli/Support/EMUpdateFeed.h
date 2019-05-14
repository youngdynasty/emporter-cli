//
//  EMUpdateFeed.h
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EMUpdate.h"

NS_ASSUME_NONNULL_BEGIN

/*! A remote feed used to find updates */
@interface EMUpdateFeed : NSObject

/*!
 The feed bundled with the current application.
 
 Feeds can be bundled by defining string values for EMUpdateFeed and EMUpdateFeedType in the main bundle,
 which are then passed to the designated initializer.
 
 If EMUpdateFeedType is not defined, it is assumed to be a GitHub release feed (EMUpdateTypeGitHubRelease).
 
 \returns A shared instance or nil if there is no feed defined in the bundle.
 */
+ (nullable instancetype)bundledFeed;

/*!
 The designated initializer.
 
 \param url  The URL used to read updates. Can be either a file URL, or a URL loadable by NSURLSession.
 \param type The type of updates supplied by the feed.
 
 \returns A new instance of \c EMUpdateFeed.
 */
- (instancetype)initWithURL:(NSURL *)url type:(EMUpdateType)type NS_DESIGNATED_INITIALIZER;

/*! The URL for the feed */
@property(nonatomic,readonly) NSURL *url;

/*! The type of updates the feed provides */
@property(nonatomic,readonly) EMUpdateType type;

/*! Read the latest updates for the feed asynchronously.
 
 \param completionHandler The block to invoke once the feed has been read. If successful (error is nil), updates will be sorted in descending order.
 */
- (void)readFeedWithCompletionHandler:(void(^)(NSArray<EMUpdate*>* __nullable updates, NSError *__nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
