//
//  EMVersion.m
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMVersion.h"

EMVersion EMVersionFromString(NSString *v) {
    // Normalize input
    v = v ?: @"0.0.0";
    if ([v hasPrefix:@"v"]) {
        v = [v substringFromIndex:1];
    }
    
    NSArray<NSString*> *versionComponents = [v componentsSeparatedByString:@"."];
    EMVersion vv = {};
    
    if (versionComponents.count >= 2) {
        vv.major = MAX(0, (int)[versionComponents[0] integerValue]);
        vv.minor = MAX(0, (int)[versionComponents[1] integerValue]);
        
        if (versionComponents.count >= 3) {
            NSArray<NSString*> *patchComponents = [versionComponents[2] componentsSeparatedByString:@"-"];
            vv.patch = MAX(0, (int)[patchComponents.firstObject integerValue]);
            
            if (patchComponents.count > 1) {
                NSString *tag = [[patchComponents subarrayWithRange:NSMakeRange(1, patchComponents.count-1)] componentsJoinedByString:@"-"];
                const char *cTag = [tag cStringUsingEncoding:NSASCIIStringEncoding];
                memcpy(&vv.tag, cTag, MIN(strlen(cTag), 254));
            }
        }
    }
    
    return vv;
}

EMVersion EMVersionEmbedded() {
    static EMVersion v = {};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (NSBundle.mainBundle != nil) {
            NSString *bundleVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            if (bundleVersion != nil) {
                v = EMVersionFromString(bundleVersion);
            }
        }
    });
    return v;
}

NSComparisonResult EMVersionCompare(EMVersion v1, EMVersion v2) {
    int vals1[] = {v1.major, v1.minor, v1.patch};
    int vals2[] = {v2.major, v2.minor, v2.patch};
    
    for (int i = 0; i < 3; i++) {
        int val1 = vals1[i];
        int val2 = vals2[i];
        
        if (val1 > val2) {
            return NSOrderedDescending;
        } else if (val1 < val2) {
            return NSOrderedAscending;
        }
    }
    
    int tagCmp = strcmp(v1.tag, v2.tag);
    
    if (tagCmp > 0) {
        return NSOrderedDescending;
    } else if (tagCmp > 0) {
        return NSOrderedAscending;
    } else {
        return NSOrderedSame;
    }
}

NSString* EMVersionDescription(EMVersion v) {
    NSString *desc = [NSString stringWithFormat:@"%d.%d.%d", v.major, v.minor, v.patch];
    return strlen(v.tag) ? [desc stringByAppendingFormat:@"-%s", v.tag] : desc;
}
