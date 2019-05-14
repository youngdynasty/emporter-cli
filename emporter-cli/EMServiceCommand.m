//
//  EMServiceCommand.m
//  emporter-cli
//
//  Created by Mikey on 01/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand-Subclass.h"
#import "EMServiceCommand.h"

#import "EMMainCommand.h"
#import "EMUtils.h"


@interface EMServiceInfoCommand : YDCommand
@end

@interface EMServiceSuspendCommand : YDCommand
@end

@interface EMServiceResumeCommand : YDCommand
@end


@implementation EMServiceCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"[SUBCOMMAND]\n\nView or update the service.";
    
    [self addCommand:[EMServiceInfoCommand new] withName:@"info" description:@"Print service info and exit"];
    [self addCommand:[EMServiceSuspendCommand new] withName:@"suspend" description:@"Suspend the service"];
    [self addCommand:[EMServiceResumeCommand new] withName:@"resume" description:@"Resume the service"];

    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count == 0) {
        return [[self commandWithPath:@"info"] executeWithArguments:arguments];
    } else {
        return [super executeWithArguments:arguments];
    }
}

@end


@implementation EMServiceInfoCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"\n\nPrint service info and exit.";
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    Emporter *emporter = [main resolveEmporter:&exitCode didLaunch:NULL];
    
    if (exitCode != YDCommandReturnCodeOK) {
        return exitCode;
    }
    
    EmporterServiceState serviceState = emporter.serviceState;
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:@{@"status": EMServiceStateDescription(serviceState, NO, NULL)}];
    } else {
        YDCommandOutputStyle stateAsciiStyle = 0;
        NSString *stateAscii = EMServiceStateDescription(serviceState, YES, &stateAsciiStyle);
        
        [YDStandardOut appendString:@" "];
        [YDStandardOut applyStyle:stateAsciiStyle withinBlock:^(id<YDCommandOutputWriter> output) {
            [output appendFormat:@" %@ ", stateAscii];
        }];
        [YDStandardOut appendFormat:@" Service state: %@\n", EMServiceStateDescription(serviceState, NO, NULL)];
    }
    
    return YDCommandReturnCodeOK;
}

@end


@implementation EMServiceSuspendCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"\n\nSuspend service and exit.";

    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    Emporter *emporter = [main resolveEmporter:&exitCode didLaunch:NULL];
    
    if (exitCode != YDCommandReturnCodeOK) {
        return exitCode;
    }
    
    NSError *error = nil;
    [emporter suspendService:&error];
    
    if (error != nil) {
        if (main.outputJSON) {
            [YDStandardOut appendJSONObject:EMJSONErrorCreateInternal(@"Could not suspend service", error)];
        } else {
            EMOutputError(YDStandardError, @"Could not suspend service: %@\n", error);
        }
        
        return YDCommandReturnCodeError;
    }
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:@{@"status": EMServiceStateDescription(emporter.serviceState, NO, NULL)}];
    }

    return YDCommandReturnCodeOK;
}

@end

@implementation EMServiceResumeCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"\n\nResume service and exit.";

    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    EMMainCommand *main = (EMMainCommand*)self.root;
    YDCommandReturnCode exitCode = YDCommandReturnCodeOK;
    Emporter *emporter = [main resolveEmporter:&exitCode didLaunch:NULL];
    
    if (exitCode != YDCommandReturnCodeOK) {
        return exitCode;
    }
    
    NSError *error = nil;
    [emporter resumeService:&error];
    
    if (error != nil) {
        if (main.outputJSON) {
            [YDStandardOut appendJSONObject:EMJSONErrorCreateInternal(@"Could not resume service", error)];
        } else {
            EMOutputError(YDStandardError, @"Could not resume service: %@\n", error);
        }
        
        return YDCommandReturnCodeError;
    }
    
    if (main.outputJSON) {
        [YDStandardOut appendJSONObject:@{@"status": EMServiceStateDescription(emporter.serviceState, NO, NULL)}];
    }
    
    return YDCommandReturnCodeOK;
}

@end
