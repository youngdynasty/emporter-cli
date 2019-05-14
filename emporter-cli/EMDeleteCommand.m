//
//  EMDeleteCommand.m
//  emporter-cli
//
//  Created by Mikey on 01/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"

#import "EMDeleteCommand.h"
#import "EMMainCommand.h"

#import "EMUtils.h"

@implementation EMDeleteCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"DIRECTORY|ID|PORT|URL\n\nDelete a URL.";
    self.numberOfRequiredArguments = 1;
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    Emporter *emporter = [main resolveEmporter:&exitCode didLaunch:NULL];
    
    if (exitCode != YDCommandReturnCodeOK) {
        return exitCode;
    }
    
    NSString *input = arguments.firstObject;
    NSURL *sourceURL = EMSourceURLFromString(input, EMSourceTypeUnknown);
    
    NSError *error = nil;
    EmporterTunnel *tunnel = sourceURL ? [emporter tunnelForURL:sourceURL error:&error] : [emporter tunnelWithIdentifier:input error:&error];
    tunnel = tunnel ? [tunnel get] : nil;
    
    if (tunnel == nil) {
        if (main.outputJSON) {
            if (error != nil) {
                [YDStandardOut appendJSONObject:EMJSONErrorCreateInternal(@"URL not found", error)];
            } else {
                [YDStandardOut appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeNotFound, @"URL not found", nil)];
            }
        } else {
            if (error != nil) {
                EMOutputError(YDStandardError, @"Could not find URL: %@.\n", error.localizedDescription);
            } else {
                EMOutputError(YDStandardError, @"URL not found.\n");
            }
        }
        
        return YDCommandReturnCodeError;
    }
    
    [tunnel delete];
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:@{@"_id": tunnel.id ?: [NSNull null]}];
    }
    
    return YDCommandReturnCodeOK;
}

@end
