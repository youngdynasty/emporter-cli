//
//  EMProcessTree.h
//  emporter-cli
//
//  Created by Mikey on 06/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! A class used to traverse processes hierarchically. */
@interface EMProcessNode : NSObject

/*! The current root node of the processes running locally. */
+ (instancetype)currentRootNode;

/*! The name of the process (may be truncated) */
@property(nonatomic,readonly) NSString *__nullable name;

/*! The pid value of the process */
@property(nonatomic,readonly) pid_t pidValue;

/*! The pid value of the parent process */
@property(nonatomic,readonly) pid_t parentPidValue;

/*! The parent process */
@property(nonatomic,readonly,weak) EMProcessNode *__nullable parent;

/*! Children of the process */
@property(nonatomic,readonly,copy) NSArray *children;

/*!
 Traverse children recursively to find a child for a pid
 \param pid The id for the process you wish to find
 \returns A child process or nil
 */
- (EMProcessNode *__nullable)childWithPid:(pid_t)pid;

@end

NS_ASSUME_NONNULL_END
