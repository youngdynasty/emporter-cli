//
//  EMEditCommand.m
//  emporter-cli
//
//  Created by Mikey on 01/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"

#import "EMEditCommand.h"
#import "EMMainCommand.h"

#import "EMUtils.h"

@implementation EMEditCommand {
    NSArray *_rawArguments;
    
    NSString *_name;
    NSString *_authUsername;
    NSString *_authPassword;

    NSString *_proxyHost;
    NSInteger _proxyPort;
    
    NSString *_directoryPath;
    NSString *_indexFile;
    
    NSNumber *_browsingEnabled;
    NSNumber *_liveReloadEnabled;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    _rawArguments = @[];
    _proxyPort = -1;
    
    self.usage = @"[OPTIONS] DIRECTORY|ID|PORT|URL\n\nEdit an existing URL. If OPTIONS are not provided, the native interface will be displayed.";
    self.numberOfRequiredArguments = 1;
    
    self.variables = @[
                       [YDCommandVariable string:&_directoryPath withName:@"--dir" usage:@"Directory path to serve (directory URLs only)"],
                       [YDCommandVariable string:&_name withName:@"--name" usage:@"Update URL to include a name"],
                       [YDCommandVariable block:EMUsernamePasswordBlock(&_authUsername, &_authPassword) withName:@"--auth" usage:@"Set HTTP Basic Auth (username:password)"],
                       [YDCommandVariable string:&_indexFile withName:@"--dir-index" usage:@"Default file to serve in directory (index.html) (directory URLs only)"],
                       [YDCommandVariable booleanNumber:&_browsingEnabled withName:@"--dir-browsing" usage:@"Enable or disable directory browsing (if index file is not found)"],
                       [YDCommandVariable booleanNumber:&_liveReloadEnabled withName:@"--live-reload" usage:@"Enable or disable live reload (directory URLs only)"],
                       [YDCommandVariable integer:&_proxyPort withName:@"--port" usage:@"Local port to serve (proxy URLs only)"],
                       [YDCommandVariable string:&_proxyHost withName:@"--host" usage:@"Overwite Host header (proxy URLs only). Use empty string to disable."],
                       ];
    
    return self;
}

- (YDCommandReturnCode)runWithArguments:(NSArray<NSString *> *)arguments {
    _rawArguments = [arguments copy];
    return [super runWithArguments:arguments];
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
    
    if (_name != nil) {
        tunnel.name = _name;
    }
    
    if (_authUsername != nil && _authPassword != nil) {
        if (IsEmporterAPIAvailable(main.emporterVersion, 0, 2)) {
            if (![tunnel passwordProtectWithUsername:_authUsername password:_authPassword]) {
                if (!main.outputJSON) {
                    EMOutputWarning(YDStandardError, @"Could not password protect URL%@\n", tunnel.isAuthEnabled ? @" because it is already password protected" : @"");
                }
            }
        } else if (!main.outputJSON) {
            EMOutputWarning(YDStandardError, @"Could not password protect URL because your version of Emporter is out of date\n");
        }
    }
    
    switch (tunnel.kind) {
        case EmporterTunnelKindProxy:
            if (_proxyPort != -1) {
                tunnel.proxyPort = @(_proxyPort);
            }
            
            if (_proxyHost != nil) {
                tunnel.proxyHostHeader = _proxyHost;
                tunnel.shouldRewriteHostHeader = ![_proxyHost isEqualToString:@""];
            }
            
            break;
        case EmporterTunnelKindDirectory:
            if (_directoryPath != nil) {
                NSURL *directoryURL = EMSourceURLFromString(_directoryPath, EMSourceTypeDirectory);
                BOOL directory = NO;
                
                if ([NSFileManager.defaultManager fileExistsAtPath:directoryURL.path isDirectory:&directory] && directory) {
                    tunnel.directory = directoryURL;
                } else if (!main.outputJSON) {
                    EMOutputWarning(YDStandardError, @"\"%@\" does not exist (or is not a directory)\n", directoryURL.lastPathComponent);
                }
            }
            
            if (_indexFile != nil) {
                tunnel.directoryIndexFile = _indexFile;
            }
            
            // API version 0.1 (Emporter 0.3.5) shipped with a bad AppleEvent
            // descriptor which incorrectly maps live reload to directory browsing
            if (IsEmporterAPIAvailable(main.emporterVersion, 0, 2)) {
                if (_liveReloadEnabled != nil) {
                    tunnel.isLiveReloadEnabled = [_liveReloadEnabled boolValue];
                }
            }
            
            if (_browsingEnabled != nil) {
                tunnel.isBrowsingEnabled = [_browsingEnabled boolValue];
            }
            
            break;
        default:
            break;
    }
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:EMJSONObjectForTunnel(tunnel, YES)];
        return YDCommandReturnCodeOK;
    }
    
    if (_rawArguments.count - arguments.count == 0) {
        [emporter configureTunnelWithURL:sourceURL error:NULL];
    }
    
    return YDCommandReturnCodeOK;
}

@end
