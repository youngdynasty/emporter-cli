//
//  EMProcessNode.m
//  emporter-cli
//
//  Created by Mikey on 06/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#include <sys/sysctl.h>

#import "EMProcessNode.h"


typedef struct kinfo_proc kinfo_proc;


@interface EMProcessNode()
@property(nonatomic,weak,setter=_setParent:) EMProcessNode *parent;
@end


@implementation EMProcessNode {
    NSMutableArray *_children;
}

+ (instancetype)currentRootNode {
    return [[self alloc] _initRootNode];
}

- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException format:@"%@ cannot be initialized directly", self.className];
    return nil;
}

- (instancetype)_initWithProccess:(kinfo_proc)proc {
    self = [super init];
    if (self == nil)
        return nil;

    _name = [NSString stringWithCString:proc.kp_proc.p_comm encoding:NSUTF8StringEncoding];
    _pidValue = proc.kp_proc.p_pid;
    _parentPidValue = proc.kp_eproc.e_ppid;
    _children = [NSMutableArray array];
    
    return self;
}

- (instancetype)_initRootNode {
    kinfo_proc *procs = NULL;
    size_t procsLength;
    
    if (_EMProcessList(&procs, &procsLength) != noErr) {
        return nil;
    }
    
    self = [super init];
    if (self == nil)
        return nil;
    
    NSMutableDictionary *nodes = [NSMutableDictionary dictionary];
    
    for (int i = 0; i < procsLength; i++) {
        EMProcessNode *process = [[EMProcessNode alloc] _initWithProccess:procs[i]];
        nodes[@(process.pidValue)] = process;
    }

    _children = [NSMutableArray array];
    
    for (NSNumber *pid in nodes) {
        EMProcessNode *node = nodes[pid];
        EMProcessNode *parent = node.pidValue == 0 && node.parentPidValue == 0 ? self : nodes[@(node.parentPidValue)];
        
        if (parent != nil) {
            [parent _addChild:node];
        }
    }
    
    free(procs);
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%d > %d) - %ld children", _name, _parentPidValue, _pidValue, _children.count];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ (%d > %d) - %@", _name, _parentPidValue, _pidValue, [_children debugDescription]];
}

- (NSArray *)children {
    return [_children copy];
}

- (void)_addChild:(EMProcessNode *)child {
    child.parent = self;
    
    NSUInteger idx = 0;
    
    for (EMProcessNode *sibling in _children) {
        if (sibling.pidValue > child.pidValue) {
            break;
        }
        idx++;
    }
    
    [_children insertObject:child atIndex:idx];
}

- (EMProcessNode *)childWithPid:(pid_t)pid {
    for (EMProcessNode *child in self.children) {
        if (child.pidValue == pid) {
            return child;
        } else {
            EMProcessNode *distantChild = [child childWithPid:pid];
            if (distantChild != nil) {
                return distantChild;
            }
        }
    }
    
    return nil;
}


// From https://developer.apple.com/library/archive/qa/qa2001/qa1123.html
static int _EMProcessList(kinfo_proc **procList, size_t *procCount)
// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
    
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
    
    *procCount = 0;
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        // Call sysctl with a NULL buffer.
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    // Clean up and establish post conditions.
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}

@end
