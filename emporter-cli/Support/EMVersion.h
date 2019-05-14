//
//  EMVersion.h
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! A contextual struct which represents a semantic version as described by https://semver.org */
typedef struct _EMVersion {
    int major, minor, patch;
    char tag[255];
} EMVersion;

/*! The version embedded in the main bundle (\c CFBundleShortVersionString) */
extern EMVersion EMVersionEmbedded(void);

/*! Parse an EMVersion from a string */
extern EMVersion EMVersionFromString(NSString *v);

/*! Compare versions */
extern NSComparisonResult EMVersionCompare(EMVersion v1, EMVersion v2);

/*! Assert version equality */
static inline BOOL EMVersionEquals(EMVersion v1, EMVersion v2) { return EMVersionCompare(v1, v2) == NSOrderedSame; }

/*! Check if a version is empty */
static inline BOOL EMVersionIsEmpty(EMVersion v) { return EMVersionEquals(v, (EMVersion){}); }

/*! A string description of a version */
extern NSString* EMVersionDescription(EMVersion v);

NS_ASSUME_NONNULL_END
