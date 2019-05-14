//
//  EMHelpCommand.m
//  emporter-cli
//
//  Created by Mikey on 23/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMHelpCommand.h"
#import "YDCommand-Subclass.h"

@implementation EMHelpCommand

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    self.usage = @"COMMAND\n\nShow help for a command.";
    self.allowsMultipleArguments = YES;
    
    return self;
}

- (YDCommandReturnCode)executeWithArguments:(NSArray<NSString *> *)arguments {
    if (arguments.count == 0) {
        [self.parent appendUsageToOutput:YDStandardOut withVariables:YES];
        return YDCommandReturnCodeOK;
    }
    
    NSString *commandName = [arguments componentsJoinedByString:@" "];
    YDCommand *command = [self.parent commandWithPath:[arguments componentsJoinedByString:@" "]];
    
    if (command == nil) {
        [YDStandardError appendFormat:@"Command not found: %@.\n", commandName];
        [YDStandardError appendString:@"\nAvailable commands:\n\n"];
        
        [self.parent appendCommandsToOutput:YDStandardError];
        
        return YDCommandReturnCodeInvalidArgs;
    }
    
    [command appendUsageToOutput:YDStandardOut withVariables:YES];
    
    return YDCommandReturnCodeOK;
}

@end

