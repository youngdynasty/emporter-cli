//
//  EMUpdate.h
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "EMVersion.h"

NS_ASSUME_NONNULL_BEGIN

/*! An immutable, contextual object to describe an update to the current application */
@interface EMUpdate : NSObject

/*! Update types are used to unmarshal property lists in various formats. */
typedef NS_ENUM(NSUInteger, EMUpdateType) {
    EMUpdateTypeKeyValues,
    EMUpdateTypeGitHubRelease
};

/*!
 The designated initalizer.
 
 \param properties  Key value pairs used to unmarshal the update's properties
 \param type        The type/source/format of the properties
 \param outError    An optional pointer to an error describing why an update could not be unmarshaled.
 
 Updates are intended to be unmarshaled from sources, such as \c EMUpdateFeed.
 
 \returns A new instance of \c EMUpdate or nil.
 */
- (nullable instancetype)initWithPropertyList:(NSDictionary *)properties type:(EMUpdateType)type error:(NSError **__nullable)outError NS_DESIGNATED_INITIALIZER;

/*! The version of the update */
@property(nonatomic,readonly) EMVersion version;

/*! The date the update was published */
@property(nonatomic,readonly) NSDate *publishDate;

/*! The title of the update */
@property(nonatomic,readonly) NSString *title;

/*! The body of the update (i.e. release notes) */
@property(nonatomic,readonly) NSString *body;

/*! Assets related to the update. */
@property(nonatomic,readonly) NSArray<NSURL*> *assetURLs;

@end

/*! Return the update type for the string (github, key_values) */
extern EMUpdateType EMUpdateTypeFromString(NSString *string);

/*! The string value of the update type (github, key_values, unknown) */
extern NSString *EMUpdateTypeDescription(EMUpdateType updateType);

NS_ASSUME_NONNULL_END
