//
//  EMGetCommand.m
//  emporter-cli
//
//  Created by Mikey on 23/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"

#import "EMGetCommand.h"
#import "EMListCommand.h"
#import "EMMainCommand.h"

#import "EMUtils.h"

@implementation EMGetCommand {
    BOOL _quiet;
    NSString *_inputHint;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[OPTIONS] DIRECTORY|ID|PORT|URL\n\nGet an existing Emporter URL configuration along with its current state.";
    self.numberOfRequiredArguments = 1;
    self.variables = @[
                       [[YDCommandVariable boolean:&_quiet withName:@"-q" usage:@"Only print URL"] variableWithAlias:@"--quiet"],
                       ];
    
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
        } else if (!_quiet) {
            if (error != nil) {
                EMOutputError(YDStandardError, @"Could not find URL: %@.\n", error.localizedDescription);
            } else {
                EMOutputError(YDStandardError, @"URL not found.\n");
            }
        }
        
        return YDCommandReturnCodeError;
    }
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:EMJSONObjectForTunnel(tunnel, YES)];
    } else if (_quiet) {
        if (tunnel.remoteUrl != nil) {
            [YDStandardOut appendFormat:@"%@\n", tunnel.remoteUrl];
        }
    } else {
        [EMListCommand writeTunnels:@[tunnel] toOutput:YDStandardOut];
    }
    
    return YDCommandReturnCodeOK;
}

@end
