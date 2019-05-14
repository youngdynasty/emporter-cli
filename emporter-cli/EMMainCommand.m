//
//  EMMainCommand.m
//  emporter-cli
//
//  Created by Mikey on 23/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"
#import "EMMainCommand.h"

#import "EMCreateCommand.h"
#import "EMDeleteCommand.h"
#import "EMEditCommand.h"
#import "EMGetCommand.h"
#import "EMHelpCommand.h"
#import "EMListCommand.h"
#import "EMServiceCommand.h"
#import "EMVersionCommand.h"
#import "EMRunCommand.h"
#import "EMUpdateCommand.h"

#import "EMUtils.h"

@implementation EMMainCommand {
    BOOL _showHelp;
    BOOL _printVersion;
    BOOL _noLaunch;
    BOOL _noColors;
    
    EMWindow *_window;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[OPTIONS] COMMAND\n\nCreate a public, secure URL to your Mac.";
    self.variables = @[
                       [YDCommandVariable boolean:&_showHelp withName:@"--help" usage:@"Print this message or show help for a command"],
                       [YDCommandVariable boolean:&_noColors withName:@"--no-colors" usage:@"Disable colored output"],
                       [YDCommandVariable boolean:&_noPrompt withName:@"--no-prompt" usage:@"Don't show prompts"],
                       [YDCommandVariable boolean:&_noLaunch withName:@"--no-launch" usage:@"Don't launch Emporter if it isn't running"],
                       [YDCommandVariable boolean:&_outputJSON withName:@"--json" usage:@"Output JSON to stdout"],
                       [[YDCommandVariable boolean:&_printVersion withName:@"-v" usage:@"Print version and quit"] variableWithAlias:@"--version"],
                       ];
    
    [self addCommand:[EMCreateCommand new] withName:@"create" description:@"Create a new URL from a local address or directory"];
    [self addCommand:[EMDeleteCommand new] withName:@"rm" description:@"Delete the URL for a local address or directory"];
    [self addCommand:[EMEditCommand new] withName:@"edit" description:@"Edit the URL for a local address or directory"];
    [self addCommand:[EMGetCommand new] withName:@"get" description:@"Get the configuration for a local address or directory"];
    [self addCommand:[EMHelpCommand new] withName:@"help" description:@"Show help for a command"];
    [self addCommand:[EMListCommand new] withName:@"list" description:@"List configured URLs"];
    [self addCommand:[EMServiceCommand new] withName:@"service" description:@"View or update the service"];
    [self addCommand:[EMVersionCommand new] withName:@"version" description:@"Show version information"];
    [self addCommand:[EMUpdateCommand new] withName:@"update" description:@"Update to the latest version"];
    [self addCommand:[EMRunCommand new] withName:@"run" description:@"Serve URLs"];

    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    YDCommandOutputStyleDisabled = YDCommandOutputStyleDisabled || _noColors || _outputJSON;
    
    [Emporter getVersion:&_emporterVersion];
    
    if (_printVersion) {
        return [[self commandWithPath:@"version"] runWithArguments:@[]];
    }
    
    if (_showHelp) {
        if (arguments.count > 0) {
            return [[self commandWithPath:@"help"] runWithArguments:arguments];
        }
        
        [self appendUsageToOutput:YDStandardOut withVariables:YES];
        return YDCommandReturnCodeOK;
    }

    return [super executeWithArguments:arguments];
}

#pragma mark -

- (Emporter *)resolveEmporter:(YDCommandReturnCode *)outReturnCode didLaunch:(BOOL *)outDidLaunch {
    if (![Emporter isInstalled]) {
        if (_outputJSON) {
            [YDStandardError appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeUnavailable, @"Emporter is not installed.", @{ @"url": Emporter.appStoreURL.absoluteString })];
        } else if (_noPrompt) {
            EMOutputError(YDStandardError, @"Emporter must be installed from the Mac App Store before using its command-line interface.\n");
        } else {
            [YDStandardError appendString:@"Emporter must be installed before using its command-line interface.\n"];
            
            if (EMRunPrompt(@"Would you like to download it from the Mac App Store?", YES)) {
                [[NSWorkspace sharedWorkspace] openURL:[Emporter appStoreURL]];
            }
        }

        if (outReturnCode != NULL) {
            (*outReturnCode) = YDCommandReturnCodeError;
        }
        
        return nil;
    }
    
    Emporter *emporter = [[Emporter alloc] init];
    
    // Launch Emporter in background if it's not running
    BOOL didLaunch = NO;
    
    if (![emporter isRunning]) {
        NSError *launchError = nil;
        
        if (_noLaunch) {
            if (_outputJSON) {
                [YDStandardError appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeBadGateway, @"Emporter is not running.", nil)];
            } else {
                EMOutputError(YDStandardError, @"Emporter is not running.\n");
            }
            
            if (outReturnCode != NULL) {
                (*outReturnCode) = YDCommandReturnCodeError;
            }
            
            return nil;
        } else if (![emporter launchInBackground:&launchError]) {
            EMOutputError(YDStandardError, @"Could not launch Emporter: %@.\n", launchError ? launchError.localizedDescription : @"Timed out");
            
            if (outReturnCode != NULL) {
                (*outReturnCode) = YDCommandReturnCodeError;
            }
            
            return nil;
        }
        
        didLaunch = YES;
        
        if (outDidLaunch != NULL) {
            (*outDidLaunch) = YES;
        }
    }
    
    // Determine user consent
    if (emporter.userConsentType == EmporterUserConsentTypeDenied) {
        NSString *hostApp = EMHostApplication() ? EMHostApplication().bundleURL.lastPathComponent : nil;
        
        if (self.outputJSON) {
            [YDStandardOut appendJSONObject:EMJSONErrorCreate(EMJSONErrorCodeUnauthorized, @"Cannot continue due to a lack of permissions.", nil)];
        } else {
            EMOutputError(YDStandardError, @"");
            
            if (hostApp != nil) {
                [YDStandardError applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeBold) withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output appendString:hostApp];
                }];
                [YDStandardError appendString:@" does not have permission to access Emporter's data.\n"];
            } else {
                [YDStandardError appendFormat:@"Cannot continue due to a lack of permissions."];
            }
            
            [YDStandardOut appendString:@"\nPermission can be granted in "];
            [YDStandardOut applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeBold) withinBlock:^(id<YDCommandOutputWriter> output) {
                [output appendString:@"System Preferences > Security & Privacy > Privacy > Automation"];
            }];
            [YDStandardOut appendString:@"\n\n"];
            
            if (!self.noPrompt && EMRunPrompt(@"Would you like to do this now?", YES)) {
                [[[NSAppleScript alloc] initWithSource:@"\
                  tell application \"System Preferences\" \n\
                  reveal anchor \"Privacy\" of pane \"com.apple.preference.security\" \n\
                  activate \n\
                  end tell\
                  "] executeAndReturnError:NULL];
            }
        }
        
        if (outReturnCode != NULL) {
            (*outReturnCode) = YDCommandReturnCodeError;
        }
    } else {
        if (outReturnCode != NULL) {
            (*outReturnCode) = YDCommandReturnCodeOK;
        }
    }
    
    return emporter;
}

- (EMWindow *)window {
    if (_window == nil) {
        _window = [[EMWindow alloc] init];
        _window.drawsBorder = YES;
        
        _window.status = @"Ctrl+C to exit";
    }
    
    return _window;
}

@end
