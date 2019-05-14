//
//  EMRunCommand.m
//  emporter-cli
//
//  Created by Mikey on 28/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMRunCommand.h"

#import "YDCommand-Subclass.h"
#import "Emporter.h"

#import "EMGetCommand.h"
#import "EMListCommand.h"
#import "EMMainCommand.h"
#import "EMUtils.h"


@interface EMRunCommand()
@property(nonatomic,readonly) Emporter *emporter;

@property(nonatomic) EMSourceType filterType;
@property(nonatomic) NSString *filterDescription;
@property(nonatomic) id filter;

@property(nonatomic,readonly) BOOL keepOpen;
@end


@implementation EMRunCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[OPTIONS]\n\nCreate and serve configured URLs.";
    
    __block EMRunCommand *weakSelf = self;
    
    BOOL (^filterBlock)(NSString *) = ^BOOL(NSString *input) {
        EMRunCommand *strongSelf = weakSelf;
        if (strongSelf != nil) {
            strongSelf.filterType = EMSourceTypeGuess(input);
            strongSelf.filterDescription = EMSourceTypeDescriptionFromString(strongSelf.filterType, input);
            
            switch (strongSelf.filterType) {
                case EMSourceTypeID:
                    strongSelf.filter = input;
                    break;
                case EMSourceTypePort:
                    strongSelf.filter = [Emporter tunnelPredicateForPort:@([input integerValue])];
                    break;
                default:
                    strongSelf.filter = [Emporter tunnelPredicateForSourceURL:EMSourceURLFromString(input, strongSelf.filterType)];
                    break;
            }
        }
        
        return YES;
    };
    
    self.variables = @[
                       [YDCommandVariable boolean:&_relaunchAutomatically withName:@"--relaunch" usage:@"Relaunch Emporter automatically"],
                       [YDCommandVariable boolean:&_keepOpen withName:@"--keep-open" usage:@"Keep Emporter open after exit if it was launched"],
                       [YDCommandVariable block:filterBlock withName:@"--filter" usage:@"Filter output by id, directory, port or URL"],
                       ];
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    
    BOOL didLaunch = NO;
    _emporter = [main resolveEmporter:&exitCode didLaunch:&didLaunch];
    _keepOpen = didLaunch ? _keepOpen : YES;
    
    if (exitCode == YDCommandReturnCodeOK) {
        // Resume service if it's suspended
        if (_emporter.serviceState == EmporterServiceStateSuspended) {
            [_emporter resumeService:NULL];
        }

        exitCode = main.outputJSON ? [self _runJSONLoop] : [self _runWindowLoop];
    }
    
    if (!_keepOpen && _emporter != nil) {
        [_emporter quit];
    }
    
    return exitCode;
}

- (YDCommandReturnCode)_runWindowLoop {
    EMMainCommand *main = (EMMainCommand*)self.root;
    
    // Lazily refresh data based on observing events
    NSMutableSet *observers = [NSMutableSet set];
    
    __block BOOL refreshData = YES;
    void (^reloadData)(void) = ^{
        refreshData = YES;
        [main.window setNeedsDisplay];
    };
    
    for (NSNotificationName notificationName in @[EmporterDidAddTunnelNotification,
                                                  EmporterDidRemoveTunnelNotification,
                                                  EmporterServiceStateDidChangeNotification,
                                                  EmporterTunnelStateDidChangeNotification,
                                                  EmporterTunnelConfigurationDidChangeNotification]) {
        [observers addObject:EMNotificationObserverBlock(notificationName, self.emporter, ^(NSNotification *note) {
            reloadData();
        })];
    }
    
    [observers addObject:EMNotificationObserverBlock(EmporterDidTerminateNotification, self.emporter, ^(NSNotification *note) {
        if (!self.relaunchAutomatically) {
            [YDStandardOut appendFormat:@"Emporter is no longer running"];
            return [main.window close];
        }
        
        [self.emporter launchInBackgroundWithCompletionHandler:^(NSError *error) {
            if (error == nil) {
                reloadData();
            } else {
                [YDStandardOut appendFormat:@"Could not relaunch Emporter: %@", error.localizedDescription];
                [main.window close];
            }
        }];
    })];
    
    __block NSArray<EmporterTunnel*> *tunnels = @[];
    __block EmporterServiceState serviceState = EmporterServiceStateSuspended;
    __block NSString *serviceConflictReason = nil;
    __block BOOL isTunnelRemoved = NO;
    
    NSString *appTitle = @"Emporter";
    EmporterVersion appVersion = main.emporterVersion;
    
    if ((appVersion.major + appVersion.minor + appVersion.minor) > 0) {
        appTitle = [appTitle stringByAppendingFormat:@" v%ld.%ld.%ld", appVersion.major, appVersion.minor, appVersion.patch];
    }
    
    [main.window runDrawLoopWithBlock:^(id <EMWindowWriter> output) {
        if (refreshData) {
            BOOL isStatic = NO;
            tunnels = [self _filteredTunnels:&isStatic];
            
            if (isStatic && tunnels.count == 0) {
                isTunnelRemoved = YES;
                [main.window close];
            }
            
            serviceState = self.emporter.serviceState;
            serviceConflictReason = self.emporter.serviceConflictReason;

            main.window.title = [NSString stringWithFormat:@"%@ [%@]", appTitle, EMServiceStateDescription(serviceState, YES, NULL)];
            
            refreshData = NO;
        }
        
        if (serviceState == EmporterServiceStateSuspended) {
            [output applyAlignment:EMWindowTextAlignmentCenter withinBlock:^(id<YDCommandOutputWriter> output) {
                [output applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeUnderline) withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output appendString:@"SERVICE IS SUSPENDED"];
                }];
                
                [output appendString:@"\n\n"];
                [output appendFormat:@"Resume the service from the menu bar or\n"];
                [output appendFormat:@"run `emporter service resume` to continue.\n"];
            }];
        } else {
            if (tunnels.count == 0) {
                [output applyAlignment:EMWindowTextAlignmentCenter withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeUnderline) withinBlock:^(id<YDCommandOutputWriter> output) {
                        [output appendString:@"NO URLS CONFIGURED"];
                    }];
                    
                    [output appendString:@"\n\n"];
                    
                    if (self.filterDescription != nil) {
                        [output appendFormat:@"URL(s) for %@ will show up automatically once it's been created.", self.filterDescription];
                    } else {
                        [output appendString:@"URLs will show up automatically once they've been created."];
                    }
                }];
            } else {
                [output applyTruncationWithinBlock:^(id<YDCommandOutputWriter> truncatedOutput) {
                    [EMListCommand writeTunnels:tunnels toOutput:truncatedOutput];
                }];
            }

            if (serviceConflictReason != nil) {
                [output applyAlignment:EMWindowTextAlignmentCenter withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output appendFormat:@"\n—\n\n%@\n", serviceConflictReason];
                    
                    if ([serviceConflictReason containsString:@"Terms of Service"]) {
                        [output appendString:@"The service will resume automatically upon acceptance.\n"];
                    }
                }];
            } else if (self.footerBlock != nil) {
                [output appendString:@"\n"];
                self.footerBlock(output);
            }
        }
    }];
    
    if (isTunnelRemoved) {
        [YDStandardOut appendString:@"URL was removed from Emporter.\n"];
    }
    
    if (main.window.isTerminated) {
        return YDCommandReturnCodeTerminated;
    } else if (![self.emporter isRunning] || isTunnelRemoved) {
        return YDCommandReturnCodeError;
    } else {
        return YDCommandReturnCodeOK;
    }
}

- (YDCommandReturnCode)_runJSONLoop {
    NSMutableSet *observers = [NSMutableSet set];
    
    // App events
    [observers addObject:EMNotificationObserverBlock(EmporterDidLaunchNotification, _emporter, ^(NSNotification *note) {
        [YDStandardOut appendJSONObject:@{@"event": @"app.launch"}];
    })];
    
    [observers addObject:EMNotificationObserverBlock(EmporterServiceStateDidChangeNotification, _emporter, ^(NSNotification *note) {
        EmporterServiceState serviceState = self.emporter.serviceState;
        
        NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:EMServiceStateDescription(serviceState, NO, NULL) ?: [NSNull null], @"state", nil];
        if (serviceState == EmporterServiceStateConflicted) {
            data[@"reason"] = self.emporter.serviceConflictReason ?: [NSNull null];
        }
        
        [YDStandardOut appendJSONObject:@{@"event": @"app.service", @"data": data}];
    })];
    
    [observers addObject:EMNotificationObserverBlock(EmporterDidTerminateNotification, _emporter, ^(NSNotification *note) {
        [YDStandardOut appendJSONObject:@{@"event": @"app.terminate", @"data": @{@"will_relaunch": @(self.relaunchAutomatically)} }];
        
        if (!self.relaunchAutomatically) {
            exit(YDCommandReturnCodeError);
        }
        
        [self.emporter launchInBackgroundWithCompletionHandler:^(NSError *error) {
            if (error == nil) {
                return;
            }
            
            [YDStandardOut appendJSONObject:@{@"event": @"app.terminate", @"data": @{@"will_relaunch": @(NO), @"error": error.localizedDescription } }];
            exit(YDCommandReturnCodeError);
        }];
    })];
    
    // URL events
    
    __block NSMutableSet *cachedTunnelIds = [NSMutableSet set];
    BOOL(^isWatchingTunnelId)(NSString*) = ^(NSString *identifier) {
        if ([cachedTunnelIds containsObject:identifier]) {
            return YES;
        } else {
            EmporterTunnel *tunnel = [self.emporter tunnelWithIdentifier:identifier error:NULL];
            if (tunnel != nil && [self _filterMatchesTunnel:tunnel]) {
                [cachedTunnelIds addObject:tunnel.id ?: @""];
                return YES;
            }
            return NO;
        }
    };
    
    [observers addObject:EMNotificationObserverBlock(EmporterDidRemoveTunnelNotification, _emporter, ^(NSNotification *note) {
        NSString *tunnelId = note.userInfo[EmporterTunnelIdentifierUserInfoKey];
        if (!isWatchingTunnelId(tunnelId)) {
            return;
        }
        
        [YDStandardOut appendJSONObject:@{@"event": @"url.removed", @"data": @{@"_id": tunnelId} }];
        
        // Signal to close if the URL we're observing by id was removed
        if ([self.filter isKindOfClass:[NSString class]] && [self.filter isEqual:tunnelId]) {
            EMBlockRunLoopStop();
        }
        
        [cachedTunnelIds removeObject:tunnelId];
    })];
    
    [observers addObject:EMNotificationObserverBlock(EmporterTunnelStateDidChangeNotification, _emporter, ^(NSNotification *note) {
        NSString *tunnelId = note.userInfo[EmporterTunnelIdentifierUserInfoKey];
        if (!isWatchingTunnelId(tunnelId)) {
            return;
        }
        
        EmporterTunnel *tunnel = [self.emporter tunnelWithIdentifier:tunnelId error:nil];
        tunnel = tunnel ? [tunnel get] : nil;
        
        NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:tunnelId, @"_id", nil];
        if (tunnel != nil) {
            [data addEntriesFromDictionary:EMJSONObjectForTunnelState(tunnel)];
        }
        
        [YDStandardOut appendJSONObject:@{@"event": @"url.state", @"data": data }];
    })];
    
    [observers addObject:EMNotificationObserverBlock(EmporterTunnelConfigurationDidChangeNotification, _emporter, ^(NSNotification *note) {
        NSString *tunnelId = note.userInfo[EmporterTunnelIdentifierUserInfoKey];
        if (!isWatchingTunnelId(tunnelId)) {
            return;
        }
        
        EmporterTunnel *tunnel = [self.emporter tunnelWithIdentifier:tunnelId error:nil];
        tunnel = tunnel ? [tunnel get] : nil;
        
        NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:tunnelId, @"_id", nil];
        if (tunnel != nil) {
            [data addEntriesFromDictionary:EMJSONObjectForTunnel(tunnel, NO)];
        }
        
        [YDStandardOut appendJSONObject:@{@"event": @"url.config", @"data": data}];

        // The tunnel's configuration has changed and it may no longer apply to our filter; remove from cache
        [cachedTunnelIds removeObject:tunnelId];
    })];
    
    // Output initial payload
    __block BOOL needsBootstrap = YES;
    
    EMBlockRunLoopRun(^{
        if (!needsBootstrap) {
            return;
        }
        needsBootstrap = NO;
        
        BOOL isStatic = NO;
        NSArray *tunnels = [self _filteredTunnels:&isStatic];
        
        if (isStatic && tunnels.count == 0) {
            [YDStandardOut appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeNotFound, @"URL not found", nil)];
            EMBlockRunLoopStop();
        } else {
            NSString *state = EMServiceStateDescription(self.emporter.serviceState ?: EmporterServiceStateSuspended, NO, NULL);
            NSMutableArray *urls = [NSMutableArray array];
            
            for (EmporterTunnel *tunnel in tunnels) {
                [urls addObject:EMJSONObjectForTunnel(tunnel, YES)];
            }
            
            [YDStandardOut appendJSONObject:@{@"event": @"init", @"data": @{@"state": state, @"urls": urls}}];
        }
    });
    
    return YDCommandReturnCodeTerminated;
}

- (NSArray<EmporterTunnel*>*)_filteredTunnels:(BOOL*)outStatic {
    if (_filter == nil) {
        return [_emporter.tunnels get] ?: @[];
    } else if ([_filter isKindOfClass:[NSString class]]) {
        if (outStatic != NULL) {
            (*outStatic) = YES;
        }
        
        EmporterTunnel *tunnel = [self.emporter tunnelWithIdentifier:self.filter error:NULL];
        tunnel = tunnel ? [tunnel get] : nil;
        return tunnel ? @[tunnel] : @[];
    } else {
        return [self.emporter.tunnels filteredArrayUsingPredicate:self.filter] ?: @[];
    }
}

- (BOOL)_filterMatchesTunnel:(EmporterTunnel *)tunnel {
    if (tunnel == nil) {
        return NO;
    } else if (_filter == nil) {
        return YES;
    } else if ([_filter isKindOfClass:[NSString class]]) {
        return [(tunnel.id ?: @"") isEqualToString:_filter];
    } else if ([_filter isKindOfClass:[NSPredicate class]]) {
        return [(NSPredicate *)_filter evaluateWithObject:tunnel];
    } else {
        return NO;
    }
}

@end
