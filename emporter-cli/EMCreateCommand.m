//
//  EMCreateCommand.m
//  emporter-cli
//
//  Created by Mikey on 01/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"
#import "EMCreateCommand.h"

#import "EMMainCommand.h"
#import "EMRunCommand.h"

#import "EMUtils.h"

@interface EMCreateCommand()
@property(nonatomic,readonly) Emporter *emporter;
@property(nonatomic,readonly) BOOL isTemporary;
@property(nonatomic,readonly) BOOL keepOpen;
@end

@implementation EMCreateCommand {
    BOOL _force;
    
    NSString *_authUsername;
    NSString *_authPassword;
    
    NSString *_name;
    
    NSString *_proxyHost;
    NSString *_directoryPath;
    NSString *_indexFile;
    
    NSNumber *_browsingEnabled;
    NSNumber *_liveReloadEnabled;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[OPTIONS] DIRECTORY|PORT|URL\n\nCreate a new URL and serve it.";
    self.numberOfRequiredArguments = 1;
    self.maximumNumberOfArguments = 1;
    
    self.variables = @[
                       [[YDCommandVariable boolean:&_force withName:@"-f" usage:@"Create a URL even if it already exists"] variableWithAlias:@"--force"],
                       [YDCommandVariable block:EMUsernamePasswordBlock(&_authUsername, &_authPassword) withName:@"--auth" usage:@"Protect the URL with HTTP Basic Auth (username:password)"],
                       [YDCommandVariable string:&_name withName:@"--name" usage:@"Create a URL based on the given name"],
                       [YDCommandVariable boolean:&_isTemporary withName:@"--rm" usage:@"Delete URL on exit if it didn't already exist"],
                       [YDCommandVariable boolean:&_keepOpen withName:@"--keep-open" usage:@"Keep Emporter open after exit if it was launched to create a URL"],
                       
                       [YDCommandVariable string:&_indexFile withName:@"--dir-index" usage:@"Default file to serve in directory (index.html) (directory URLs only)"],
                       [YDCommandVariable booleanNumber:&_browsingEnabled withName:@"--dir-browsing" usage:@"Enable or disable directory browsing (if index file is not found)"],
                       [YDCommandVariable booleanNumber:&_liveReloadEnabled withName:@"--live-reload" usage:@"Enable or disable live reload (directory URLs only)"],
                       [YDCommandVariable string:&_proxyHost withName:@"--host" usage:@"Overwrite Host header (proxy URLs only). Use empty string to disable."],
                       ];
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    BOOL didLaunchEmporter = NO;
    
    _emporter = [main resolveEmporter:&exitCode didLaunch:&didLaunchEmporter];
    _keepOpen = didLaunchEmporter ? _keepOpen : YES;
    
    EmporterTunnel *tunnel = nil;
    
    if (exitCode == YDCommandReturnCodeOK) {
        BOOL existed = NO;
        NSError *error = nil;
        
        tunnel = [self _createTunnelWithInput:arguments.firstObject existed:&existed error:&error];
        
        if (error != nil) {
            if (main.outputJSON) {
                [YDStandardOut appendJSONObject:EMJSONErrorCreateInternal(@"Could not create URL", error)];
            } else {
                EMOutputError(YDStandardError, @"Could not create URL: %@\n", error.localizedDescription);
            }
            
            exitCode = YDCommandReturnCodeError;
        } else if (existed && !_force) {
            _isTemporary = NO;

            if (main.outputJSON) {
                [YDStandardOut appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeConflict, @"URL already exists", @{ @"_id": tunnel.id ?: [NSNull null] })];
                exitCode = YDCommandReturnCodeError;
            } else {
                EMOutputWarning(YDStandardOut, @"A URL with the same source aready exists\n");
                if (main.noPrompt || !EMRunPrompt(@"Would you like to use the existing URL?", YES)) {
                    [YDStandardOut appendString:@"Try running again with the --force flag set\n"];
                    exitCode = YDCommandReturnCodeError;
                }
            }
        } else if (tunnel != nil) {
            // Configure tunnel
            [self _configureTunnel:tunnel];
        }
    }
    
    // Mount if there was not an existing error
    if (exitCode == YDCommandReturnCodeOK && tunnel != nil) {
        exitCode = [self _mountTunnel:tunnel];
    }
    
    // Remove tunnel if needed
    if (_isTemporary && tunnel != nil) {
        if ([_emporter isRunning]) {
            [tunnel delete];
        } else if (!IsEmporterAPIAvailable(main.emporterVersion, 0, 2)) {
            if (!main.outputJSON) {
                EMOutputWarning(YDStandardError, @"URL configuration was not deleted\n");
            }
        }
    }
    
    // Close Emporter if needed
    if (!_keepOpen && _emporter != nil) {
        [_emporter quit];
    }
    
    return exitCode;
}

- (EmporterTunnel *)_createTunnelWithInput:(NSString *)input existed:(BOOL*)outExisted error:(NSError **)outError {
    EMMainCommand *main = (EMMainCommand*)self.root;
    EMSourceType sourceType = EMSourceTypeGuess(input);
    
    // Assume the GUID is a directory
    if (sourceType == EMSourceTypeID) {
        sourceType = EMSourceTypeDirectory;
    }
    
    NSURL *sourceURL = EMSourceURLFromString(input, sourceType);
    
    // Check if tunnel exists with the given sourceURL
    EmporterTunnel *tunnel = [_emporter tunnelForURL:sourceURL error:NULL];
    tunnel = tunnel ? [tunnel get] : nil;
    
    if (tunnel != nil) {
        if (outExisted != NULL) {
            (*outExisted) = YES;
        }
        
        // Return unless force flag is set
        if (!_force) {
            return tunnel;
        }
    }
    
    NSString *name = _name;
    if (name == nil && sourceType == EMSourceTypeDirectory) {
        name = [sourceURL.lastPathComponent lowercaseString];
    }
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (name != nil) {
        dict[@"name"] = name;
    }
    
    if (_isTemporary && IsEmporterAPIAvailable(main.emporterVersion, 0, 2)) {
        dict[@"isTemporary"] = @(_isTemporary);
    }
        
    return [_emporter createTunnelWithURL:sourceURL properties:dict error:outError];
}

- (void)_configureTunnel:(EmporterTunnel *)tunnel {
    EMMainCommand *main = (EMMainCommand*)self.root;
    
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
}

- (YDCommandReturnCode)_mountTunnel:(EmporterTunnel *)tunnel {
    EMRunCommand *run = (EMRunCommand *)[self.root commandWithPath:@"run"];
    run.footerBlock = ^(id<EMWindowWriter> output) {
        [output applyAlignment:EMWindowTextAlignmentCenter withinBlock:^(id<YDCommandOutputWriter> output) {
            if (self.isTemporary) {
                if (self.keepOpen) {
                    [output appendString:@"URL will be removed and Emporter will terminate on exit"];
                } else {
                    [output appendString:@"URL will be removed on exit"];
                }
            } else {
                if (self.keepOpen) {
                    [output appendString:@"URL will remain configured after Emporter terminates on exit"];
                } else {
                    [output appendString:@"URL will remain configured after exit"];
                }
            }
        }];
    };
    
    YDCommandReturnCode exitCode = [run runWithArguments:@[@"--filter", tunnel.id ?: @""]];
    run.footerBlock = nil;
    
    return exitCode;
}

@end
