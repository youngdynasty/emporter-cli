//
//  EMUpdateFeed.m
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMUpdateFeed.h"
#import "EMUpdate.h"
#import "EMVersion.h"

@implementation EMUpdateFeed

+ (instancetype)bundledFeed {
    static dispatch_once_t onceToken;
    static EMUpdateFeed *bundledFeed = nil;
    
    dispatch_once(&onceToken, ^{
        if (NSBundle.mainBundle != nil) {
            NSString *feedURLString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"EMUpdateFeed"];
            
            if (feedURLString != nil) {
                NSURL *feedURL = [NSURL URLWithString:feedURLString];
                NSString *feedTypeString = [NSBundle.mainBundle objectForInfoDictionaryKey:@"EMUpdateFeedType"];
                EMUpdateType feedType = feedTypeString ? EMUpdateTypeFromString(feedTypeString) : EMUpdateTypeGitHubRelease;
                
                bundledFeed = [[self alloc] initWithURL:feedURL type:feedType];
            }
        }
    });
    
    return bundledFeed;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"-[%@ %@] cannot be called directly", self.className, NSStringFromSelector(_cmd)];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithURL:(NSURL *)url type:(EMUpdateType)type {
    self = [super init];
    if (self == nil)
        return nil;
    
    _url = url;
    _type = type;
    
    return self;
}

- (void)readFeedWithCompletionHandler:(void (^)(NSArray<EMUpdate*> *, NSError *))completionHandler {
    NSURL *feedURL = _url;
    
    if (_type == EMUpdateTypeGitHubRelease && [(feedURL.host ?: @"") isEqualToString:@"github.com"]) {
        NSString *feedPath = [[NSString stringWithFormat:@"/repos/%@", feedURL.path] stringByStandardizingPath];
        
        if (![feedPath.lastPathComponent isEqualToString:@"releases"]) {
            feedPath = [feedPath stringByAppendingPathComponent:@"releases"];
        }
        
        feedURL = [NSURL URLWithString:feedPath relativeToURL:[NSURL URLWithString:@"https://api.github.com"]];
    }
    
    void(^handleFeedData)(NSData *, NSError *) = ^(NSData *data, NSError *error) {
        if (error != nil) {
            return completionHandler(nil, error);
        }
        
        NSArray<EMUpdate*> *items = nil;
        
        switch (self.type) {
            case EMUpdateTypeGitHubRelease:
                items = [self _updateItemsFromJSONData:data error:&error];
                break;
            default:
                error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EPROTONOSUPPORT userInfo:nil];
                break;
        }
        
        if (error != nil) {
            completionHandler(nil, error);
        } else {
            completionHandler([items ?: @[] sortedArrayUsingComparator:^NSComparisonResult(EMUpdate *u1, EMUpdate *u2) {
                return EMVersionCompare(u2.version, u1.version);
            }], nil);
        }
    };
    
    if ([feedURL isFileURL]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *error = nil;
            NSData *data = [NSData dataWithContentsOfURL:feedURL options:0 error:&error];
            handleFeedData(data, error);
        });
    } else {
        [[[NSURLSession sharedSession] dataTaskWithURL:feedURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            handleFeedData(data, error);
        }] resume];
    }
}

- (NSArray *)_updateItemsFromJSONData:(NSData *)data error:(NSError **)outError {
    NSArray *plists = [NSJSONSerialization JSONObjectWithData:data options:0 error:outError];
    if (plists == nil) {
        return nil;
    }
    
    NSMutableArray<EMUpdate*> *items = [NSMutableArray array];
    
    for (NSDictionary *plist in plists) {
        if (![plist isKindOfClass:[NSDictionary class]]) {
            if (outError != NULL) {
                (*outError) = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
            }
            return nil;
        }
        
        EMUpdate *item = [[EMUpdate alloc] initWithPropertyList:plist type:_type error:outError];
        if (item == nil) {
            return nil;
        }
        [items addObject:item];
    }
    
    return items;
}

@end
