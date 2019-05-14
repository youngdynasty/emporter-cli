//
//  EMSpinner.m
//  emporter-cli
//
//  Created by Mike Pulaski on 09/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "EMSpinner.h"
#import "YDCommandOutput.h"


@implementation EMSpinner {
    NSTimer *_timer;
    YDCommandOutput *_output;
}

- (instancetype)init {
    return [self initWithOutput:YDStandardOut];
}

- (instancetype)initWithOutput:(YDCommandOutput *)output {
    self = [super init];
    if (self == nil)
        return nil;
    
    _output = output;
    
    return self;
}

- (void)dealloc {
    if (_timer != nil) {
        [_timer invalidate];
    }
}

- (void)setMessage:(NSString *)message {
    if (![NSThread isMainThread]) {
        return dispatch_sync(dispatch_get_main_queue(), ^{ [self setMessage:message]; });
    }
    
    if (_message != message) {
        _message = message;
        
        if (_timer != nil) {
            [_timer fire];
        }
    }
}

- (BOOL)isSpinning {
    if (![NSThread isMainThread]) {
        __block BOOL isSpinning = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            isSpinning = [self isSpinning];
        });
        return isSpinning;
    }
    
    return _timer != nil && [_timer isValid];
}

- (void)startSpinning {
    if (![NSThread isMainThread]) {
        return dispatch_sync(dispatch_get_main_queue(), ^{ [self startSpinning]; });
    }

    if (_timer != nil) {
        return;
    }

    __block uint8 i = 0;
    __weak EMSpinner *weakSelf = self;
    
    _timer = [NSTimer timerWithTimeInterval:0.15 repeats:YES block:^(NSTimer *timer) {
        EMSpinner *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [self.output appendString:@"\r\033[K"];
        
        [self.output applyStyle:YDCommandOutputStyleWithAttribute(YDCommandOutputStyleAttributeInvert) withinBlock:^(id<YDCommandOutputWriter> output) {
            static NSString *spinnerComponents[] = { @"\\", @"|", @"/", @"—" };
            [output appendFormat:@" %@ ", spinnerComponents[(i++ % 4)]];
        }];
        
        [self.output appendFormat:@" %@", strongSelf.message ?: @""];
    }];

    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)stopSpinning:(BOOL)resetLine {
    if (![NSThread isMainThread]) {
        return dispatch_sync(dispatch_get_main_queue(), ^{ [self stopSpinning:resetLine]; });
    }
    
    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
        
        if (resetLine) {
            [_output appendString:@"\r\033[K"];
        }
    }
}

@end
