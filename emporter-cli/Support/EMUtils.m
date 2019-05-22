//
//  EMUtils.m
//  emporter-cli
//
//  Created by Mikey on 24/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <sys/sysctl.h>

#import "EMUtils.h"
#import "EMProcessNode.h"

#import "YDCommandOutput.h"

EMJSONError EMJSONErrorCreate(EMJSONErrorCode code, NSString *message, NSDictionary *userInfo) {
    return @{@"domain": @"net.youngdynasty.emporter-cli", @"code": @(code), @"message": message, @"userInfo": userInfo ?: [NSNull null] };
}

EMJSONError EMJSONErrorCreateInternal(NSString *message, NSError *error) {
    return EMJSONErrorCreate(EMJSONErrorCodeInternal, message, @{@"sourceError": error.localizedDescription });
}

NSDictionary* EMJSONObjectForTunnelState(EmporterTunnel *tunnel) {
    NSMutableDictionary *tunnelProperties = [NSMutableDictionary dictionary];
    
    tunnelProperties[@"state"] = EMTunnelStateDescription(tunnel, NO, NULL);
    
    if (tunnel.state == EmporterTunnelStateConflicted) {
        tunnelProperties[@"conflictReason"] = tunnel.conflictReason ?: [NSNull null];
    }
    
    tunnelProperties[@"url"] = tunnel.remoteUrl ?: [NSNull null];
    
    return tunnelProperties;
}

NSDictionary* EMJSONObjectForTunnel(EmporterTunnel *tunnel, BOOL includeState) {
    NSMutableDictionary *tunnelProperties = [NSMutableDictionary dictionary];
    
    tunnelProperties[@"_id"] = tunnel.id ?: [NSNull null];
    
    // EmporterKit doesn't send the right AppleEvent to get the tunnel name (a ScriptingBridge.framework bug)
    tunnelProperties[@"name"] = (tunnel.properties ?: @{})[@"name"] ?: [NSNull null];
    
    tunnelProperties[@"isEnabled"] = @(tunnel.isEnabled);
    tunnelProperties[@"isAuthEnabled"] = @(tunnel.isAuthEnabled);
    
    if (tunnel.kind == EmporterTunnelKindProxy) {
        tunnelProperties[@"kind"] = @"proxy";
        tunnelProperties[@"proxyPort"] = tunnel.proxyPort ?: [NSNull null];
        tunnelProperties[@"proxyRewriteHostHeader"] = @(tunnel.shouldRewriteHostHeader);
        
        NSString *hostHeader = tunnel.proxyHostHeader;
        if (hostHeader != nil && hostHeader.length == 0) {
            hostHeader = nil;
        }
        
        tunnelProperties[@"proxyHostHeader"] = hostHeader ?: @"localhost";
    } else {
        tunnelProperties[@"kind"] = @"directory";
        tunnelProperties[@"directory"] = tunnel.directory ? tunnel.directory.path : (tunnel.properties[@"directoryPath"] ?: [NSNull null]);
        
        tunnelProperties[@"isBrowsingEnabled"] = @(tunnel.isBrowsingEnabled);
        tunnelProperties[@"isLiveReloadEnabled"] = @(tunnel.isLiveReloadEnabled);

        NSString *indexFile = tunnel.directoryIndexFile;
        if (indexFile != nil && indexFile.length == 0) {
            indexFile = nil;
        }
        
        tunnelProperties[@"directoryIndexFile"] = indexFile ?: @"index.html";
    }

    if (includeState) {
        [tunnelProperties addEntriesFromDictionary:EMJSONObjectForTunnelState(tunnel)];
    }
    
    return tunnelProperties;
}

#pragma mark -

static NSString *_EMTunnelStateDescription(EmporterTunnelState tunnelState, BOOL ascii) {
    switch (tunnelState) {
        case EmporterTunnelStateInitializing:
            return ascii ? @"…" : @"initializing";
        case EmporterTunnelStateDisconnecting:
            return ascii ? @"…" : @"disconnecting";
        case EmporterTunnelStateDisconnected:
            return ascii ? @"~" : @"disconnected";
        case EmporterTunnelStateConnecting:
            return ascii ? @"…" : @"connecting";
        case EmporterTunnelStateConnected:
            return ascii ? @"✓" : @"connected";
        case EmporterTunnelStateConflicted:
            return ascii ? @"✘" : @"conflicted";
        default:
            return ascii ? @"?" : @"unknown";
    }
}

NSString *EMTunnelStateDescription(EmporterTunnel *tunnel, BOOL ascii, YDCommandOutputStyle *outStyle) {
    EmporterTunnelState tunnelState = tunnel.state ?: EmporterTunnelStateDisconnected;
    NSString *description = _EMTunnelStateDescription(tunnelState, ascii);
    
    if (outStyle != NULL) {
        switch (tunnelState) {
            case EmporterTunnelStateConnected: {
                NSString *name = tunnel.properties[@"name"] ?: tunnel.name ?: @"";
                NSString *urlString = tunnel.remoteUrl ?: @"";
                
                if ([urlString localizedCaseInsensitiveContainsString:name]) {
                    (*outStyle) = YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorGreen, YDCommandOutputStyleAttributeBold);
                } else {
                    (*outStyle) = YDCommandOutputStyleMake(YDCommandOutputStyleColorBlack, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeBold);
                }
                
                break;
            }
            case EmporterTunnelStateConflicted:
                (*outStyle) = YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorRed, YDCommandOutputStyleAttributeBold);
                break;
            case EmporterTunnelStateConnecting:
                (*outStyle) = YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeBold);
                break;
            case EmporterTunnelStateInitializing:
            case EmporterTunnelStateDisconnecting:
            case EmporterTunnelStateDisconnected:
            default:
                (*outStyle) = YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeInvert);
                break;
        }
    }
    
    return description;
}

YDCommandOutputStyle EMTunnelStateOutputStyle(EmporterTunnel *tunnel) {
    EmporterTunnelState tunnelState = tunnel.state ?: EmporterTunnelStateDisconnected;
    
    switch (tunnelState) {
        case EmporterTunnelStateConnected: {
            NSString *name = tunnel.properties[@"name"] ?: tunnel.name ?: @"";
            NSString *urlString = tunnel.remoteUrl ?: @"";
            
            if ([urlString localizedCaseInsensitiveContainsString:name]) {
                return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorGreen, YDCommandOutputStyleAttributeBold);
            } else {
                return YDCommandOutputStyleMake(YDCommandOutputStyleColorBlack, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeBold);
            }
        }
        case EmporterTunnelStateConflicted:
            return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorRed, YDCommandOutputStyleAttributeBold);
        case EmporterTunnelStateConnecting:
            return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeBold);
        case EmporterTunnelStateInitializing:
        case EmporterTunnelStateDisconnecting:
        case EmporterTunnelStateDisconnected:
        default:
            return YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeInvert);
    }
}

NSString *EMTunnelSourceDescription(EmporterTunnel *tunnel) {
    switch (tunnel.kind) {
        case EmporterTunnelKindProxy:
            return [NSString stringWithFormat:@"%@:%@", tunnel.shouldRewriteHostHeader ? tunnel.proxyHostHeader : @"localhost", tunnel.proxyPort ?: @""];
        case EmporterTunnelKindDirectory:
            return [NSString stringWithFormat:@"%@/", [((id)tunnel.directory ?: @"") lastPathComponent]];
        default:
            return @"";
    }
}

static YDCommandOutputStyle _EMServiceStateOutputStyle(EmporterServiceState serviceState) {
    switch (serviceState) {
        case EmporterServiceStateConnecting:
            return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeBold);
        case EmporterServiceStateConnected:
            return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorGreen, YDCommandOutputStyleAttributeBold);
        case EmporterServiceStateConflicted:
            return YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorRed, YDCommandOutputStyleAttributeBold);
        case EmporterServiceStateSuspended:
            return YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeInvert);
        default:
            return 0;
    }
}

NSString *EMServiceStateDescription(EmporterServiceState serviceState, BOOL ascii, YDCommandOutputStyle *__nullable outStyle) {
    if (outStyle != NULL) {
        (*outStyle) = _EMServiceStateOutputStyle(serviceState);
    }
    
    switch (serviceState) {
        case EmporterServiceStateConnecting:
            return ascii ? @"…" : @"connecting";
        case EmporterServiceStateConnected:
            return ascii ? @"✓" : @"connected";
        case EmporterServiceStateSuspended:
            return ascii ? @"—" : @"suspended";
        case EmporterServiceStateConflicted:
            return ascii ? @"✘" : @"offline";
        default:
            return ascii ? @"?" : @"unknown";
    }
}

void EMOutputSuccess(id <YDCommandOutputWriter> output, NSString *format, ...) {
    [output applyStyle:YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorGreen, YDCommandOutputStyleAttributeNormal) withinBlock:^(id<YDCommandOutputWriter> output) {
        [output appendString:@" ✓ "];
    }];
    
    va_list args;
    va_start(args, format);
    [output appendString:@" "];
    [output appendString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
}

void EMOutputSuccessWithFormat(id <YDCommandOutputWriter> output, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    EMOutputSuccess(output, [[NSString alloc] initWithFormat:format arguments:args]);
    va_end(args);
}

void EMOutputWarning(id <YDCommandOutputWriter> output, NSString *format, ...) {
    [output applyStyle:YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorYellow, YDCommandOutputStyleAttributeNormal) withinBlock:^(id<YDCommandOutputWriter> output) {
        [output appendString:@" ! "];
    }];
    
    va_list args;
    va_start(args, format);
    [output appendString:@" "];
    [output appendString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
}

void EMOutputError(YDCommandOutput *output, NSString *format, ...) {
    [output applyStyle:YDCommandOutputStyleMake(YDCommandOutputStyleColorWhite, YDCommandOutputStyleColorRed, YDCommandOutputStyleAttributeNormal) withinBlock:^(id<YDCommandOutputWriter> output) {
        [output appendString:@" ✘ "];
    }];
    
    va_list args;
    va_start(args, format);
    [output appendString:@" "];
    [output appendString:[[NSString alloc] initWithFormat:format arguments:args]];
    va_end(args);
}

#pragma mark -

EMSourceType EMSourceTypeGuess(NSString *str) {
    if ([[NSUUID alloc] initWithUUIDString:str] != nil) {
        return EMSourceTypeID;
    } else if (![str containsString:@"."] && [str integerValue] > 0) {
        return EMSourceTypePort;
    }
    
    // Check for a well-formed URL
    NSURL *url = [NSURL URLWithString:str];
    if (url != nil) {
        NSString *urlScheme = url.scheme ?: @"";
        
        if ([@[@"http", @"https"] containsObject:urlScheme]) {
            return EMSourceTypeURL;
        } else if ([urlScheme isEqualToString:@"file"]) {
            return EMSourceTypeDirectory;
        } else if ([url.host ?: @"" containsString:@".emporter."]) {
            return EMSourceTypeURL;
        }
    }
    
    // Check for an actual directory
    NSURL *pwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES];
    NSURL *childDir = [[NSURL fileURLWithPath:[str stringByExpandingTildeInPath] isDirectory:YES relativeToURL:pwd] fileReferenceURL];
    BOOL isDirectory = NO;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:childDir.path isDirectory:&isDirectory]) {
        return EMSourceTypeDirectory;
    }
    
    // Time to really guess
    NSString *firstComponent = [str.pathComponents firstObject];
    NSUInteger colonIndex  = [firstComponent rangeOfString:@":"].location;
    
    if (colonIndex != NSNotFound && [[firstComponent substringFromIndex:colonIndex+1] integerValue] != 0) {
        return EMSourceTypeURL;
    }
    
    if ([@[@"localhost", @"127.0.0.1"] containsObject:firstComponent] || [@[@"dev", @"local"] containsObject:firstComponent.pathExtension]) {
        return EMSourceTypeURL;
    }
    
    return EMSourceTypeDirectory;
}

NSString* EMSourceTypeDescription(EMSourceType type) {
    switch (type) {
        case EMSourceTypeDirectory:
            return @"directory";
        case EMSourceTypeID:
            return @"id";
        case EMSourceTypePort:
            return @"port";
        case EMSourceTypeURL:
            return @"url";
        default:
            return @"unknown";
    }
}

NSString* EMSourceTypeDescriptionFromString(EMSourceType type, NSString *input) {
    switch (type) {
        case EMSourceTypeDirectory:
            return [[input lastPathComponent] stringByAppendingString:@"/"];
        case EMSourceTypePort:
            return [NSString stringWithFormat:@"port %@", input];
        case EMSourceTypeURL: {
            NSURL *url = EMSourceURLFromString(input, type);
            if (url == nil) {
                return input;
            }
            
            return [NSString stringWithFormat:@"%@:%@", url.host ?: @"localhost", url.port ?: @(80)];
        }
        case EMSourceTypeID:
            return input;
        case EMSourceTypeUnknown:
        default:
            return @"";
    }
}

NSURL* EMSourceURLFromString(NSString *input, EMSourceType type) {
    switch (type == EMSourceTypeUnknown ? EMSourceTypeGuess(input) : type) {
        case EMSourceTypeDirectory: {
            NSURL *pwd = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES];
            NSURL *fileURL = [NSURL fileURLWithPath:[input stringByExpandingTildeInPath] isDirectory:YES relativeToURL:pwd];
            return fileURL.fileReferenceURL ?: fileURL;
        }
        case EMSourceTypePort:
            return [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%@", input]];
        case EMSourceTypeURL:
            if (![input hasPrefix:@"http"]) {
                input = [@"http://" stringByAppendingString:input];
            }
            return [NSURL URLWithString:input];
        case EMSourceTypeID:
        case EMSourceTypeUnknown:
            
        default:
            return nil;
    }
}

BOOL EMRunPrompt(NSString *prompt, BOOL defaultValue) {
    [YDStandardOut appendFormat:@"%@\n[%@]", prompt, defaultValue ? @"Y/n" : @"y/N"];
    
    char input[6] = {0};
    fscanf(stdin, "%5[^\n]", input);
    
    if (strlen(input) == 0) {
        return defaultValue;
    }
    
    return [[NSString stringWithFormat:@"%s", input] boolValue];
}

YDCommandVariableBlock EMUsernamePasswordBlock(NSString *__strong *outUsername, NSString *__strong *outPassword) {
    return ^BOOL(NSString *input) {
        NSRange colon = [input rangeOfString:@":"];
        if (colon.location == NSNotFound) {
            return NO;
        }
        
        NSString *username = [input substringToIndex:colon.location];
        NSString *password = [input substringFromIndex:colon.location+1];
        
        if (username.length == 0 || password.length == 0) {
            return NO;
        }
        
        if (outUsername != NULL) {
            (*outUsername) = username;
        }
        
        if (outPassword != NULL) {
            (*outPassword) = password;
        }
        
        return YES;
    };
}


#pragma mark -


@interface __EMDeferredBlock : NSObject
@property(nonatomic,copy) dispatch_block_t value;
@end

@implementation __EMDeferredBlock
- (void)dealloc { _value(); }
@end

id _EMDeferredBlock(dispatch_block_t block) {
    __EMDeferredBlock *deferred = [[__EMDeferredBlock alloc] init];
    deferred.value = block;
    return deferred;
}

id EMNotificationObserverBlock(NSNotificationName name, id object, void(^block)(NSNotification *)) {
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:name object:object queue:nil usingBlock:^(NSNotification *note) {
        @autoreleasepool { block(note); }
    }];
    return _EMDeferredBlock(^{ [[NSNotificationCenter defaultCenter] removeObserver:observer]; });
}

static void _NOOP(void *info) {}

void EMBlockRunLoopRun(dispatch_block_t block) {
    // Schedule run loop source so we can break our loop as needed
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext runLoopCtx = { .perform = &_NOOP };
    CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(NULL, 1, &runLoopCtx);
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    
    // Add termination termination signal handlers
    __block BOOL isTerminated = NO;
    NSMutableSet *signalSources = [NSMutableSet set];
    
    int signals[] = {SIGTERM, SIGINT, SIGUSR2, -1};
    for (int i = 0; signals[i] != -1; i++) {
        struct sigaction action = { 0 };
        action.sa_handler = SIG_IGN;
        sigaction(signals[i], &action, NULL);
        
        dispatch_source_t sigSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, signals[i], 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(sigSource, ^{
            isTerminated = true;
            CFRunLoopSourceSignal(runLoopSource);
            CFRunLoopWakeUp(runLoop);
        });
        [signalSources addObject:sigSource];

        dispatch_resume(sigSource);
    }
    
    do {
        if (block != NULL) {
            @autoreleasepool { block(); }
        }
    } while (!isTerminated && CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, true) != kCFRunLoopRunStopped);
    
    // Restore default signal actions
    for (dispatch_source_t sigSource in signalSources) {
        struct sigaction action = { 0 };
        action.sa_handler = SIG_DFL;
        sigaction((int)dispatch_source_get_handle(sigSource), &action, NULL);
        
        dispatch_source_cancel(sigSource);
    }
    
    CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
}

void EMBlockRunLoopStop(void) { kill(getpid(), SIGUSR2); }

#pragma mark -

NSRunningApplication* EMHostApplication() {
    static dispatch_once_t onceToken;
    static NSRunningApplication *hostApplication = nil;
    dispatch_once(&onceToken, ^{
        EMProcessNode *rootProcessNode = [EMProcessNode currentRootNode];
        EMProcessNode *currentProcessNode = [rootProcessNode childWithPid:getpid()];
        
        while (hostApplication == nil && currentProcessNode != nil && (currentProcessNode = currentProcessNode.parent)) {
            hostApplication = [NSRunningApplication runningApplicationWithProcessIdentifier:currentProcessNode.pidValue];
        }
    });
    
    return hostApplication;
}
