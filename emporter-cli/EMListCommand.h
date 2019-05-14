//
//  EMListCommand.h
//  emporter-cli
//
//  Created by Mikey on 24/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "YDCommand.h"
#import "YDCommandOutput.h"

NS_ASSUME_NONNULL_BEGIN

@class EmporterTunnel;

@interface EMListCommand : YDCommand

+ (void)writeTunnels:(NSArray<EmporterTunnel*> *)tunnels toOutput:(id <YDCommandOutputWriter>)output;

@end

NS_ASSUME_NONNULL_END
