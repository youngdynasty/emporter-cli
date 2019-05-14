//
//  EMListCommand.m
//  emporter-cli
//
//  Created by Mikey on 24/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"

#import "EMGetCommand.h"
#import "EMListCommand.h"
#import "EMMainCommand.h"
#import "EMUtils.h"


@implementation EMListCommand {
    BOOL _quiet;
    NSInteger _limit;
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[OPTIONS]\n\nList URLs along with their configuration and current state.";
    self.variables = @[
                       [[YDCommandVariable boolean:&_quiet withName:@"-q" usage:@"Only print URL strings"] variableWithAlias:@"--quiet"],
                       [[YDCommandVariable integer:&_limit withName:@"-n" usage:@"Show the last n configured URLs."] variableWithAlias:@"--last"],
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
    
    NSArray *tunnels = emporter.tunnels ?: @[];
    
    if (_limit > 0 && _limit < tunnels.count) {
        tunnels = [tunnels subarrayWithRange:NSMakeRange(0, _limit)];
    }
    
    if (main.outputJSON) {
        NSMutableArray *payload = [NSMutableArray array];
        
        for (EmporterTunnel *tunnel in tunnels) {
            [payload addObject:EMJSONObjectForTunnel(tunnel, YES)];
        }
        
        [YDStandardOut appendJSONObject:payload];
    } else if (_quiet) {
        for (EmporterTunnel *tunnel in tunnels) {
            if (tunnel.remoteUrl) {
                [YDStandardOut appendFormat:@"%@\n", tunnel.remoteUrl];
            }
        }
    } else {
        [EMListCommand writeTunnels:tunnels toOutput:YDStandardOut];
    }
    
    return YDCommandReturnCodeOK;
}

+ (void)writeTunnels:(NSArray<EmporterTunnel*> *)tunnels toOutput:(id <YDCommandOutputWriter>)output {
    BOOL isServicePartial = NO;
    BOOL didHitServiceLimits = NO;
    
    BOOL(^isTunnelPartial)(EmporterTunnel*) = ^BOOL(EmporterTunnel *tunnel) {
        NSString *remoteURL = tunnel.remoteUrl;
        return remoteURL != nil && ![remoteURL localizedCaseInsensitiveContainsString:tunnel.properties[@"name"] ?: tunnel.name ?: @""];
    };
    
    BOOL(^isTunnelAtCapacity)(EmporterTunnel*) = ^BOOL(EmporterTunnel *tunnel) {
        return [(tunnel.conflictReason ?: @"") containsString:@"Too many"];
    };
    
    for (EmporterTunnel *tunnel in tunnels) {
        isServicePartial = isServicePartial || isTunnelPartial(tunnel);
        didHitServiceLimits = didHitServiceLimits || isTunnelAtCapacity(tunnel);
        
        if (didHitServiceLimits) {
            break;
        }
    }
    
    [output applyTabWidth:5 withinBlock:^(id<YDCommandOutputWriter> output) {
        [output appendString:[@[@"      SOURCE", @"URL"] componentsJoinedByString:@"\t"]];
        
        if (didHitServiceLimits || isServicePartial) {
            [output appendString:@"\t"];
        }
        
        [output appendString:@"\n"];
        
        for (EmporterTunnel *tunnel in tunnels) {
            [output appendString:@" "];
            {
                YDCommandOutputStyle stateStyle = 0;
                NSString *stateDescription = EMTunnelStateDescription(tunnel, YES, &stateStyle);
                
                [output applyStyle:stateStyle withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output appendFormat:@" %@ ", stateDescription];
                }];
            }
            [output appendString:@"  "];

            [output appendString:[@[EMTunnelSourceDescription(tunnel), @""] componentsJoinedByString:@"\t"]];
            
            if (tunnel.state == EmporterTunnelStateConflicted && !isTunnelAtCapacity(tunnel)) {
                [output appendString:tunnel.conflictReason ?: @""];
            } else {
                [output applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeUnderline) withinBlock:^(id<YDCommandOutputWriter> output) {
                    [output appendString:tunnel.remoteUrl ?: @""];
                }];
            }
            
            if (didHitServiceLimits || isServicePartial) {
                [output appendString:@"\t"];
                
                if (isTunnelPartial(tunnel)) {
                    [output appendString:@"*"];
                } else if (isTunnelAtCapacity(tunnel)) {
                    [output appendString:@"**"];
                }
            }
            
            [output appendString:@"\n"];
        }
    }];
    
    if (isServicePartial || didHitServiceLimits) {
        [output appendString:@"\n"];

        if (isServicePartial) {
            [output appendString:@" *  Paid subscriptions are required to reserve URL names.\n"];
        }
        
        if (didHitServiceLimits) {
            [output appendString:@" ** Too many URLs are active.\n"];
        }
        
        if (isServicePartial) {
            [output appendString:@"\nPurchase a subscription within the app for custom names, faster speeds, and more URLs.\n"];
        }
    }
}

@end
