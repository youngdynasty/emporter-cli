//
//  EMVersionCommand.m
//  emporter-cli
//
//  Created by Mikey on 30/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"

#import "EMVersionCommand.h"
#import "EMMainCommand.h"


@implementation EMVersionCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"COMMAND\n\nPrint version.";
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand *)self.root;
    
    NSString *cliVersion = nil;
    NSUInteger cliBuildNumber = 0;
    
    if (NSBundle.mainBundle != nil) {
        cliVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        cliBuildNumber = MAX(0, [[NSBundle.mainBundle objectForInfoDictionaryKey:(__bridge NSString *) kCFBundleVersionKey] integerValue]);
    }

#ifdef DEBUG
    cliVersion = cliVersion ? [cliVersion stringByAppendingString:@"-dev"] : nil;
#endif
    
    EmporterVersion app = main.emporterVersion;
    NSString *appVersion = nil;
    NSString *apiVersion = nil;

    if ((app.major + app.minor + app.patch) > 0) {
        appVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", app.major, app.minor, app.patch];
    }
    
    if ((app.api.major + app.api.minor + app.api.patch) > 0) {
        apiVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", app.api.major, app.api.minor, app.api.patch];
    }
    
    if (main.outputJSON) {
        id cliData = @{ @"build": @(cliBuildNumber), @"version": cliVersion ?: [NSNull null]};
        id appData = @{ @"build": appVersion ? @(app.buildNumber) : [NSNull null], @"version": appVersion ?: [NSNull null], @"url": Emporter.appStoreURL.absoluteString };
        id apiData = @{ @"version": apiVersion ?: [NSNull null]};
        
        [YDStandardOut appendJSONObject:@{@"cli": cliData, @"app": appData, @"api": apiData}];
    } else {
        [YDStandardOut appendFormat:@"CLI %@ (%ld)", cliVersion, cliBuildNumber];
        
        if (appVersion != nil) {
            [YDStandardOut appendFormat:@" / Emporter %@ (%ld)", appVersion, app.buildNumber];
        }

        if (apiVersion != nil) {
            [YDStandardOut appendFormat:@" / API %@", apiVersion];
        }
        
        [YDStandardOut appendString:@"\n"];
    }
    
    return YDCommandReturnCodeOK;
}

@end

