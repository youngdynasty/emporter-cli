//
//  EMMainCommand.h
//  emporter-cli
//
//  Created by Mikey on 23/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand.h"
#import "Emporter.h"
#import "EMWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMMainCommand : YDCommandTree

@property(nonatomic,readonly) BOOL outputJSON;
@property(nonatomic,readonly) BOOL noPrompt;

@property(nonatomic,readonly) EmporterVersion emporterVersion;

// Emporter may launch but without the correct permissions. Make sure to check the return code for OK before continuing.
- (Emporter *__nullable)resolveEmporter:(YDCommandReturnCode *__nullable)returnCode didLaunch:(BOOL *__nullable)didLaunch;

@property(nonatomic, readonly) EMWindow *window;

@end

NS_ASSUME_NONNULL_END
