//
//  EMUpdate.m
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMUpdate.h"

#define CLASS_OR_NIL(v, k)      (v != nil && [v isKindOfClass:[k class]] ? v : nil)

@implementation EMUpdate

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithPropertyList:(NSDictionary *)properties type:(EMUpdateType)type error:(NSError **)outError {
    self = [super init];
    if (self == nil)
        return nil;
    
    switch (type) {
        case EMUpdateTypeGitHubRelease: {
            static NSISO8601DateFormatter *dateFormatter = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                dateFormatter = [[NSISO8601DateFormatter alloc] init];
            });
            
            _title = CLASS_OR_NIL(properties[@"name"], NSString) ?: @"";
            _body = CLASS_OR_NIL(properties[@"body"], NSString) ?: @"";
            _publishDate = [dateFormatter dateFromString:CLASS_OR_NIL(properties[@"published_at"], NSString) ?: @""] ?: [NSDate distantPast];
            _version = EMVersionFromString(CLASS_OR_NIL(properties[@"tag_name"], NSString) ?: @"");
            
            if (EMVersionIsEmpty(_version)) {
                _version = EMVersionFromString(CLASS_OR_NIL(properties[@"name"], NSString) ?: @"");
            }
            
            NSMutableArray *assetURLs = [NSMutableArray array];
            
            for (NSDictionary *asset in properties[@"assets"] ?: @[]) {
                NSString *urlString = CLASS_OR_NIL(asset[@"browser_download_url"], NSString);
                if (urlString == nil) {
                    continue;
                }
                
                NSURL *assetURL = [NSURL URLWithString:urlString];
                if (assetURL != nil) {
                    [assetURLs addObject:assetURL];
                }
            }
            
            _assetURLs = [assetURLs copy];
            
            break;
        }
        case EMUpdateTypeKeyValues:
            _title = CLASS_OR_NIL(properties[@"title"], NSString) ?: @"";
            _body = CLASS_OR_NIL(properties[@"body"], NSString) ?: @"";
            _publishDate = CLASS_OR_NIL(properties[@"publishDate"], NSDate) ?: [NSDate distantPast];
            _assetURLs = [CLASS_OR_NIL(properties[@"url"], NSArray) ?: @[] copy];
            _version = EMVersionFromString(CLASS_OR_NIL(properties[@"version"], NSString) ?: @"");
            break;
        default:
            if (outError != NULL) {
                (*outError) = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPROTONOSUPPORT userInfo:nil];
            }
            return nil;
    }
    
    if (_assetURLs == nil || _assetURLs.count == 0) {
        if (outError != NULL) {
            (*outError) = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
        }
        return nil;
    }
    
    return self;
}

@end

EMUpdateType EMUpdateTypeFromString(NSString *string) {
    if ([string isEqualToString:@"github"]) {
        return EMUpdateTypeGitHubRelease;
    }
    
    return EMUpdateTypeKeyValues;
}

NSString *EMUpdateTypeDescription(EMUpdateType updateType) {
    switch (updateType) {
        case EMUpdateTypeGitHubRelease:
            return @"github";
        case EMUpdateTypeKeyValues:
            return @"key_values";
        default:
            return @"unknown";
    }
}
