//
//  EMUpdater.m
//  emporter-cli
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMUpdater.h"
#import "EMCodeSignature.h"


@interface EMUpdater() <NSFileManagerDelegate>
@property(nonatomic,readonly) NSURL *_executableURL;
@property(nonatomic,readonly) dispatch_queue_t _q;
@end

@implementation EMUpdater
@synthesize _q = _q;
@synthesize _executableURL = _executableURL;

static void *qContext = &qContext;

+ (void)applyWithURL:(NSURL *)url stateHandler:(void(^)(EMUpdaterState state, NSProgress *__nullable progress, NSError *__nullable error))stateHandler {
    [[[self alloc] init] applyWithURL:url stateHandler:stateHandler];
}

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    _executableURL = NSBundle.mainBundle ? NSBundle.mainBundle.executableURL : [NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments.firstObject];
    
    _q = dispatch_queue_create("net.youngdynasty.emporter-cli.updater", NULL);
    dispatch_queue_set_specific(_q, qContext, qContext, NULL);
    
    return self;
}

- (void)_sync:(dispatch_block_t)block {
    if (dispatch_get_specific(qContext) == NULL) {
        dispatch_sync(_q, block);
    } else {
        block();
    }
}

typedef void(^_EMUpdaterStateHandler)(EMUpdaterState, NSProgress *, NSError *);

- (void)applyWithURL:(NSURL *)url stateHandler:(_EMUpdaterStateHandler)block {
    dispatch_async(_q, ^{
        if ([url isFileURL]) {
            [self _extractFileURL:url withStateHandler:block];
        } else {
            [self _downloadURL:url withStateHandler:block];
        }
    });
}

- (void)_downloadURL:(NSURL *)url withStateHandler:(_EMUpdaterStateHandler)block {
    dispatch_assert_queue(_q);
    
    __block NSURLSessionDownloadTask *download = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        [self _sync:^{
            if (error == nil) {
                [self _extractFileURL:location withStateHandler:block];
            } else {
                if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
                    block(EMUpdaterStateCanceled, nil, nil);
                } else {
                    block(EMUpdaterStateComplete, nil, error);
                }
            }
        }];
    }];
    
    [download resume];
    
    NSProgress *progress = [NSProgress discreteProgressWithTotalUnitCount:1];
    [progress addChild:download.progress withPendingUnitCount:1];
    
    progress.cancellationHandler = ^{
        if (download != nil) {
            [download cancel];
            download = nil;
        }
    };
    
    block(EMUpdaterStateDownloading, progress, nil);
}

- (void)_extractFileURL:(NSURL *)fileURL withStateHandler:(_EMUpdaterStateHandler)block {
    dispatch_assert_queue(_q);

    NSProgress *progress = [NSProgress discreteProgressWithTotalUnitCount:10];
    NSTask *task = [NSTask new];
    progress.cancellationHandler = ^{
        // Cancel task synchronously so we can guarantee the task setup/teardown is handled correctly
        [self _sync:^{
            if ([task isRunning]) {
                [task terminate];
            }
        }];
    };

    block(EMUpdaterStateExtracting, progress, nil);
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil];
    NSProgress *unarchiveProgress = [NSProgress discreteProgressWithTotalUnitCount:attributes ? [attributes[NSFileSize] unsignedIntegerValue] : 0];
    
    [progress addChild:unarchiveProgress withPendingUnitCount:8];
    
    [self _unarchiveTarballAtFileURL:fileURL usingTask:task progress:unarchiveProgress completionHandler:^(NSArray<NSURL *> *contents, NSError *error) {
        dispatch_assert_queue(self._q);
        
        if ([progress isCancelled]) {
            return block(EMUpdaterStateCanceled, nil, nil);
        }
        
        // Find executable
        NSURL *newExecutableURL = nil;
        for (NSURL *curURL in contents) {
            if ([curURL.lastPathComponent isEqualToString:self._executableURL.lastPathComponent]) {
                newExecutableURL = curURL;
                break;
            }
        }
        
        if (newExecutableURL == nil) {
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:@{NSLocalizedDescriptionKey: @"Executable not found in update package"}];
            return block(EMUpdaterStateComplete, nil, error);
        }
        
        // Verify signature
        BOOL isSignatureValid = NO;
        EMCodeSignature *updateSignature = [[EMCodeSignature alloc] initWithFileURL:newExecutableURL error:&error];
        if (updateSignature != nil) {
            isSignatureValid = [[EMCodeSignature embeddedSignature] matches:updateSignature error:&error];
        }
        
        if (!isSignatureValid) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[NSLocalizedDescriptionKey] = @"Executable in update package has an invalid signature";
            
            if (error != nil) {
                userInfo[NSUnderlyingErrorKey] = error;
            }
            
            error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSExecutableNotLoadableError userInfo:userInfo];
            return block(EMUpdaterStateComplete, nil, error);
        }
        
        // Replace binary
        [[NSFileManager defaultManager] replaceItemAtURL:self._executableURL
                                           withItemAtURL:newExecutableURL
                                          backupItemName:[NSString stringWithFormat:@".%@-temp", newExecutableURL.lastPathComponent]
                                                 options:NSFileManagerItemReplacementUsingNewMetadataOnly
                                        resultingItemURL:NULL
                                                   error:&error];
        
        block(EMUpdaterStateComplete, nil, error);
    }];
}

- (void)_unarchiveTarballAtFileURL:(NSURL *)fileURL usingTask:(NSTask *)task progress:(NSProgress *)progress completionHandler:(void(^)(NSArray<NSURL*> *contents, NSError *error))block {
    dispatch_assert_queue(_q);
    
    NSError *error = nil;
    NSFileHandle *input = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
    if (error != nil) {
        return block(nil, error);
    }
    
    NSFileManager *fileManager = [NSFileManager new];
    fileManager.delegate = self;

    NSURL *tempDir = [fileManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:_executableURL create:YES error:&error];
    if (tempDir == nil) {
        return block(nil, error);
    }
    
    NSPipe *errorPipe = [NSPipe pipe];
    NSPipe *inputPipe = [NSPipe pipe];

    task.launchPath = @"/usr/bin/tar";
    task.arguments = @[@"-zxC", tempDir.path];
    task.standardInput = inputPipe;
    task.standardOutput = nil;
    task.standardError = errorPipe;
    
    [task launch];
    
    // Pipe data to task and wait for it to end in a different queue so we don't block our queue (to correctly handle cancelation)
    dispatch_group_t ioGroup = dispatch_group_create();
    
    dispatch_group_async(ioGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *chunk = nil;
        
        while (task.isRunning && (chunk = [input readDataOfLength:256*1024]).length > 0) {
            [inputPipe.fileHandleForWriting writeData:chunk];
            progress.completedUnitCount += chunk.length;
        }
        
        [inputPipe.fileHandleForWriting closeFile];
        [task waitUntilExit];
    });
    
    // Wait for task to finish
    dispatch_group_notify(ioGroup, _q, ^{
        if (task.terminationStatus == 0) {
            NSError *error = nil;
            NSArray *contents = [fileManager contentsOfDirectoryAtURL:tempDir includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsPackageDescendants error:&error];
            
            if (contents == nil) {
                block(nil, error);
            } else {
                block(contents, nil);
            }
        } else {
            NSString *errorMessage = [[NSString alloc] initWithData:[errorPipe.fileHandleForReading readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            block(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{ NSLocalizedFailureErrorKey: errorMessage }]);
        }
        
        [fileManager removeItemAtURL:tempDir error:NULL];
    });
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtURL:(NSURL *)URL { return YES; }
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error removingItemAtURL:(NSURL *)URL { return YES; }

@end
