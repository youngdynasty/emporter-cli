//
//  EMUpdateCommand.m
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"
#import "EMUpdateCommand.h"

#import "EMUtils.h"
#import "EMUpdateFeed.h"
#import "EMUpdater.h"
#import "EMSpinner.h"
#import "EMMainCommand.h"


@implementation EMUpdateCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"\n\nUpdate to the latest version.";
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    
    __block EMSpinner *spinner = [EMSpinner new];
    __block YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:@{@"status": @"checking", @"message": @"Checking for updates..."}];
    } else {
        spinner.message = @"Checking for updates...";
        [spinner startSpinning];
    }
    
    __block BOOL updaterFinished = NO;
    __block NSProgress *updaterProgress = nil;
    dispatch_queue_t progressQueue = dispatch_queue_create("net.youngdynasty.emporter-cli.update-progress", NULL);
    
    [[EMUpdateFeed bundledFeed] readFeedWithCompletionHandler:^(NSArray<EMUpdate *> *updates, NSError *error) {
        if (error != nil) {
            if (main.outputJSON) {
                [YDStandardOut appendJSONObject:@{@"status": @"error",
                                                  @"message": @"Update failed",
                                                  @"didUpdate": @(NO),
                                                  @"error": EMJSONErrorCreateInternal(@"Could not fetch updates", error)}];
            } else {
                [YDStandardError appendFormat:@"\r"];
                EMOutputError(YDStandardError, @"Could not fetch updates. Please try again later.\n", error);
            }
            
            exitCode = YDCommandReturnCodeError;
            return EMBlockRunLoopStop();
        }

        EMUpdate *latestUpdate = updates.firstObject;
        
        if (latestUpdate == nil || EMVersionCompare(latestUpdate.version, EMVersionEmbedded()) != NSOrderedDescending) {
            if (main.outputJSON) {
                [YDStandardOut appendJSONObject:@{@"status": @"ok",
                                                  @"message": @"You're up to date! 🎉",
                                                  @"version": EMVersionDescription(EMVersionEmbedded()),
                                                  @"didUpdate": @(false)}];
            } else {
                [YDStandardOut appendFormat:@"\r\nYou're up to date! 🎉"];
            }
            
            return EMBlockRunLoopStop();
        }
        
        NSArray *possibleTarballs = @[@"emporter.tar.gz", [NSString stringWithFormat:@"emporter-%@.tar.gz", EMVersionDescription(latestUpdate.version)]];
        NSUInteger tarballIdx = [latestUpdate.assetURLs indexOfObjectPassingTest:^BOOL(NSURL *url, NSUInteger idx, BOOL *stop) {
            return [possibleTarballs containsObject:url.lastPathComponent];
        }];
        
        if (tarballIdx == NSNotFound) {
            if (main.outputJSON) {
                [YDStandardOut appendJSONObject:@{@"status": @"error",
                                                  @"message": @"Update failed",
                                                  @"didUpdate": @(NO),
                                                  @"error": EMJSONErrorCreateInternal(@"Could not find package for update", error)}];
            } else {
                [YDStandardError appendFormat:@"\r"];
                EMOutputError(YDStandardError, @"Could not find package for update. Please try again later.\n", error);
            }
            
            exitCode = YDCommandReturnCodeError;
            return EMBlockRunLoopStop();
        }
        
        if (!main.outputJSON) {
            [YDStandardOut appendFormat:@"\rFound new update! "];
            [YDStandardOut applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeBold) withinBlock:^(id<YDCommandOutputWriter> output) {
                [output appendFormat:@"v%@", EMVersionDescription(latestUpdate.version)];
            }];
            [YDStandardOut appendFormat:@"\n"];
        }
        
        [EMUpdater applyWithURL:latestUpdate.assetURLs[tarballIdx] stateHandler:^(EMUpdaterState state, NSProgress *progress, NSError *error) {
            dispatch_sync(progressQueue, ^{ updaterProgress = progress; });
            
            switch (state) {
                case EMUpdaterStateDownloading:
                    if (main.outputJSON) {
                        [YDStandardOut appendJSONObject:@{@"status": @"downloading",
                                                          @"message": @"Downloading update...",
                                                          @"version": EMVersionDescription(latestUpdate.version)}];
                    } else {
                        spinner.message = @"Downloading update...";
                    }
                    
                    return;
                case EMUpdaterStateExtracting:
                    if (main.outputJSON) {
                        [YDStandardOut appendJSONObject:@{@"status": @"extracting",
                                                          @"message": @"Extracting update...",
                                                          @"version": EMVersionDescription(latestUpdate.version)}];
                    } else {
                        spinner.message = @"Extracting update...";
                    }
                    
                    return;
                case EMUpdaterStateCanceled:
                    exitCode = YDCommandReturnCodeTerminated;
                    return;
                case EMUpdaterStateComplete:
                    if (main.outputJSON) {
                        if (error == nil) {
                            [YDStandardOut appendJSONObject:@{@"status": @"ok",
                                                              @"message": @"Update complete!",
                                                              @"didUpdate": @(YES),
                                                              @"version": EMVersionDescription(latestUpdate.version)}];
                        } else {
                            [YDStandardOut appendJSONObject:@{@"status": @"error",
                                                              @"message": @"Update failed",
                                                              @"didUpdate": @(NO),
                                                              @"version": EMVersionDescription(latestUpdate.version),
                                                              @"error": EMJSONErrorCreateInternal(@"Could not apply update", error)}];
                        }
                    } else {
                        [spinner stopSpinning:YES];
                        
                        if (error == nil) {
                            EMOutputSuccess(YDStandardOut, @"Updated complete!\n");
                        } else {
                            EMOutputError(YDStandardOut, @"Could not apply update\n    ");
                            [YDStandardError appendFormat:@"%@\n", error.localizedDescription];
                        }
                    }
                    
                    exitCode = error ? YDCommandReturnCodeError : YDCommandReturnCodeOK;
                    updaterFinished = YES;
                    EMBlockRunLoopStop();
                    
                    return;
            }
        }];
    }];
    
    EMBlockRunLoopRun(nil);
    
    if ([spinner isSpinning]) {
        [spinner stopSpinning:NO];
        [YDStandardOut appendString:@"\n"];
    }
    
    if (!updaterFinished) {
        dispatch_sync(progressQueue, ^{
            if (updaterProgress != nil) {
                [updaterProgress cancel];
            }
        });
        
        if (exitCode == YDCommandReturnCodeOK) {
            exitCode = YDCommandReturnCodeTerminated;
        }
    }
    
    return exitCode;
}

@end
