//
//  EMRunCommand.h
//  emporter-cli
//
//  Created by Mikey on 28/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YDCommand.h"
#import "EMWindow.h"

NS_ASSUME_NONNULL_BEGIN

@interface EMRunCommand : YDCommand

@property(nonatomic) EMWindowWriterBlock __nullable footerBlock;
@property(nonatomic) BOOL relaunchAutomatically;

@end

NS_ASSUME_NONNULL_END
