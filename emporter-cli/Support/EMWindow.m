//
//  EMWindow.m
//  emporter-cli
//
//  Created by Mikey on 28/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <curses.h>
#import <sys/ioctl.h>

#import "EMWindow.h"


@interface _EMWindowWriter : NSObject
- (instancetype)initWithWindow:(WINDOW *)w output:(id <YDCommandOutputWriter>)output;

@property(nonatomic, readonly) WINDOW *window;
@property(nonatomic, readonly) id<YDCommandOutputWriter> output;
@end


@interface EMWindow()
@property(nonatomic,readonly) dispatch_queue_t _q;
@property(nonatomic,setter=_setIsTerminated:) BOOL isTerminated;
@property(nonatomic,setter=_setWakeUpBlock:) void(^_wakeUpBlock)(void);
@end

@implementation EMWindow {
    BOOL _needsResize;
}
@synthesize _q = _q;

- (instancetype)init {
    self = [super init];
    if (self == nil)
        return nil;
    
    _q = dispatch_queue_create("net.youngdynasty.emporter-cli.window", NULL);
    
    return self;
}

- (void)setNeedsDisplay {
    [self _wakeUp];
}

- (void)_setNeedsResize:(BOOL)flag {
    _needsResize = flag;
    [self _wakeUp];
}

- (void)setTitle:(NSString *)title {
    _title = title;
    [self _wakeUp];
}

- (void)setDrawsBorder:(BOOL)drawsBorder {
    _drawsBorder = drawsBorder;
    [self _wakeUp];
}

- (void)close {
    _isClosed = YES;
    [self _wakeUp];
}

- (void)_setIsTerminated:(BOOL)isTerminated {
    _isTerminated = isTerminated;
    [self _wakeUp];
}

- (void)runDrawLoopWithBlock:(void(^)(id <EMWindowWriter> output))block {
    // Handle termination signals
    dispatch_source_t sigIntSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(sigIntSource, ^{ self.isTerminated = true; });

    dispatch_source_t sigTermSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(sigTermSource, ^{ self.isTerminated = true; });

    // Handle resize signals
    dispatch_source_t sigResizeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGWINCH, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(sigResizeSource, ^{
        struct winsize ws;
        ioctl(0, TIOCGWINSZ, &ws);
        
        if (is_term_resized(ws.ws_row, ws.ws_col)) {
            [self _setNeedsResize:YES];
        }
    });
    
    // Override default termination signals
    {
        struct sigaction action = { 0 };
        action.sa_handler = SIG_IGN;
        
        sigaction(SIGINT, &action, NULL);
        sigaction(SIGTERM, &action, NULL);
    }
    
    dispatch_resume(sigIntSource);
    dispatch_resume(sigTermSource);
    dispatch_resume(sigResizeSource);

    _isClosed = NO;
    _isTerminated = NO;
    
    // Detach a new run loop so that only explicit calls to wake up our draw routine
    // will cause redraws. We must also create a new run loop source so this method
    // will block until the draw loop has exited.
    __block BOOL isRunning = YES;
    
    CFRunLoopRef callerRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext context = { .perform = &_NOOPRunLoop };
    CFRunLoopSourceRef wakeUpSource = CFRunLoopSourceCreate(NULL, 0, &context);
    CFRunLoopAddSource(callerRunLoop, wakeUpSource, kCFRunLoopCommonModes);
    
    [self _detachRunLoopWithinBlock:^{
        [self _runDrawLoopBlock:block];

        isRunning = NO;
        CFRunLoopSourceSignal(wakeUpSource);
        CFRunLoopWakeUp(callerRunLoop);
    }];
    
    while (isRunning) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, YES);
    }

    CFRunLoopRemoveSource(callerRunLoop, wakeUpSource, kCFRunLoopCommonModes);
    CFRelease(wakeUpSource);
    
    dispatch_source_cancel(sigIntSource);
    dispatch_source_cancel(sigTermSource);
    dispatch_source_cancel(sigResizeSource);
    
    // Restore default termination signals
    {
        struct sigaction action = { 0 };
        action.sa_handler = SIG_DFL;
        sigaction(SIGINT, &action, NULL);
        sigaction(SIGTERM, &action, NULL);
    }
}

- (void)_runDrawLoopBlock:(void(^)(id <EMWindowWriter> output))block {
    // Initialize window
    WINDOW *main = initscr();
    curs_set(0);
    
    if (!YDCommandOutputStyleDisabled && has_colors()) {
        start_color();
        use_default_colors();
        
        // Default colors are defined as -1, and defined colors are between 0-7.
        // These map to our color values defined in YDCommandOutputStyle when offset by 1
        for (int i = -1; i < 8; i++) {
            for (int j = -1; j < 8; j++) {
                init_pair(_colorPairValue(i, j), i, j);
            }
        }
    }
    
    WINDOW *w = NULL;
    
    do {
        // Wait until a draw event if we've already drawn our window
        if (w != NULL && CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, true) == kCFRunLoopRunTimedOut) {
            continue;
        }
        
        // Break when closed / terminated
        if (_isTerminated || _isClosed) {
            break;
        }
        
        if (_needsResize) {
            struct winsize ws;
            ioctl(0, TIOCGWINSZ, &ws);
            resize_term(ws.ws_row, ws.ws_col);
            
            [self _setNeedsResize:NO];
        }
        
        // Calculate screen / window boundaries
        int screenHeight = getmaxy(main);
        int screenWidth = getmaxx(main);
        
        int winY = (_drawsBorder ? 1 : 0) + (_title ? 1 : 0);
        int winX = _drawsBorder ? 2 : 0;
        
        int winHeight = screenHeight - winY*2;
        int winWidth = screenWidth - winX*2;
        
        if (w == NULL) {
            w = newwin(winY, winX, winHeight, winWidth);
        } else {
            mvwin(w, winY, winX);
            wresize(w, winHeight, winWidth);
        }
        
        wclear(main);
        
        // Draw outer window chrome
        if (_drawsBorder) {
            box(main, 0, 0);
        }
        
        if (_title) {
            wattrset(main, A_STANDOUT);
            mvwprintw(main, 0, (screenWidth - (int)_title.length - 2) / 2, " %s ", [_title UTF8String]);
            wattrset(main, 0);
        }
        
        if (_status) {
            mvwprintw(main, screenHeight - 1, (screenWidth - (int)_status.length - 2) / 2, " %s ", [_status UTF8String]);
        }
        
        // Draw window contents using a pipe to our writer on the main thread
        @autoreleasepool {
            __block NSData *data = nil;
            
            // Invoke block from the main thread
            dispatch_sync(dispatch_get_main_queue(), ^ {
                data = [YDCommandOutput UTF8DataCapturedByBlock:^(id<YDCommandOutputWriter> pipe) {
                    block((id<EMWindowWriter>) [[_EMWindowWriter alloc] initWithWindow:w output:pipe]);
                }];
            });
            
            NSString *contents = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
            
            wclear(w);
            wattrset(w, 0);
            
            YDCommandOutputStyleStringEnumerateUsingBlock(contents, ^(NSString *substring, YDCommandOutputStyle *style, BOOL *stop) {
                if (style != NULL) {
                    wattrset(w, _windowAttributes(*style));
                } else {
                    wprintw(w, "%s", [substring UTF8String]);
                }
            });
        }
        
        // Refresh the screen
        wrefresh(main);
        wrefresh(w);
    } while (true);
    
    if (w != NULL) {
        wclear(w);
    }
    
    wclear(main);
    endwin();
}

#pragma mark -

// Color pairs in ncurses cannot exceed 255; shift both colors to fit a single integer
static inline uint8 _colorPairValue(f, b) {
    return (((f + 1) << 4) + (b + 1));
}

static int _windowAttributes(YDCommandOutputStyle style) {
    int attrs = 0;
    
    switch (YDCommandOutputStyleGetAttribute(style)) {
    case YDCommandOutputStyleAttributeBold:         attrs |= A_BOLD; break;
    case YDCommandOutputStyleAttributeUnderline:    attrs |= A_UNDERLINE; break;
    case YDCommandOutputStyleAttributeInvert:       attrs |= A_STANDOUT; break;
    default: break;
    }
    
    int foregroundColor = YDCommandOutputStyleGetForegroundColor(style) - 1;
    int backgroundColor = YDCommandOutputStyleGetBackgroundColor(style) - 1;
    
    if (backgroundColor != -1 || foregroundColor != -1) {
        attrs |= COLOR_PAIR(_colorPairValue(foregroundColor, backgroundColor));
    }
    
    return attrs;
}

static void _NOOPRunLoop(void *info) {}

- (void)_detachRunLoopWithinBlock:(void(^)(void))block {
    [NSThread detachNewThreadWithBlock:^{
        @autoreleasepool {
            // Create a source which we can use to wake the thread up
            CFRunLoopRef runLoop = CFRunLoopGetCurrent();
            CFRunLoopSourceContext runLoopSourceCtx = { .perform = &_NOOPRunLoop };
            CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(NULL, 0, &runLoopSourceCtx);

            CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
            CFRunLoopWakeUp(runLoop);
            
            // Signal the source so the first run of our loop will always return immediately
            CFRunLoopSourceSignal(runLoopSource);

            // Set block to wake up the runloop
            dispatch_sync(self._q, ^{
                self._wakeUpBlock = ^{
                    CFRunLoopSourceSignal(runLoopSource);
                    CFRunLoopWakeUp(runLoop);
                };
            });
            
            block();
            
            // Remove wake up block
            dispatch_sync(self._q, ^{ self._wakeUpBlock = nil; });
            
            // Remove source
            CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
            CFRelease(runLoopSource);
        }
    }];
}

- (void)_wakeUp {
    dispatch_async(_q, ^{
        if (self._wakeUpBlock != nil) {
            self._wakeUpBlock();
        }
    });
}

@end


@implementation _EMWindowWriter

- (instancetype)initWithWindow:(WINDOW *)w output:(id <YDCommandOutputWriter>)output {
    self = [super init];
    if (self == nil)
        return nil;
    
    _window = w;
    _output = output;
    
    return self;
}

#pragma mark - YDCommandOutputWriter Proxy

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [super methodSignatureForSelector:aSelector] ?: [(id)_output methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([(id)_output respondsToSelector:invocation.selector])
        [invocation invokeWithTarget:_output];
    else {
        [super forwardInvocation:invocation];
    }
}

#pragma mark -

- (void)applyAlignment:(EMWindowTextAlignment)alignment withinBlock:(YDCommandOutputWriterBlock)block {
    if (alignment == EMWindowTextAlignmentLeft) {
        return block(_output);
    }
    
    NSData *data = [YDCommandOutput UTF8DataCapturedByBlock:block];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSUInteger windowWidth = MAX(getmaxx(_window) - 1, 0);
    
    if (windowWidth == 0) {
        return [_output appendString:string];
    }
    
    // Align each line captured by the block
    [self _enumerateLinesInString:string usingBlock:^(NSString *line, NSString *linebreak, BOOL *stop) {
        __block NSUInteger lineLength = 0;

        // Discard color strings when calculating the line length (as they're invisible)
        YDCommandOutputStyleStringEnumerateUsingBlock(line, ^(NSString *substring, YDCommandOutputStyle *style, BOOL *stop) {
            if (style == NULL) {
                lineLength += substring.length;
            }
        });
        
        // Calculate the padding needed for alignment based on the current window width
        NSUInteger paddingSize = 0;

        if (lineLength > 0 && lineLength < windowWidth) {
            if (alignment == EMWindowTextAlignmentRight) {
                paddingSize = windowWidth - lineLength;
            } else if (alignment == EMWindowTextAlignmentCenter) {
                paddingSize = (windowWidth - lineLength) / 2;
            }
        }
        
        // Pad the line using unstyled output; otherwise our padding may include background colors which would look weird
        if (paddingSize > 0) {
            [self.output applyStyle:0 withinBlock:^(id<YDCommandOutputWriter> unstyledOutput) {
                [unstyledOutput appendString:[@"" stringByPaddingToLength:paddingSize withString:@" " startingAtIndex:0]];
            }];
        }
        
        // Truncate the line to fit the window
        [self _appendTruncatedLine:line withEllipsis:YES];
        
        // Add the linebreak (don't assume \n)
        [self.output appendString:linebreak];
    }];
}

- (void)applyTruncationWithinBlock:(YDCommandOutputWriterBlock)block {
    NSData *data = [YDCommandOutput UTF8DataCapturedByBlock:block];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    NSUInteger windowWidth = MAX(getmaxx(_window) - 1, 0);
    
    if (windowWidth == 0) {
        return [_output appendString:string];
    }
    
    // Truncate each line in the string captured by our block
    [self _enumerateLinesInString:string usingBlock:^(NSString *line, NSString *linebreak, BOOL *stop) {
        [self _appendTruncatedLine:line withEllipsis:YES];
        [self.output appendString:linebreak];
    }];
}

- (void)_appendTruncatedLine:(NSString *)line withEllipsis:(BOOL)ellipsis {
    if (line.length == 0) {
        return;
    }
    
    // Calculate the window width and return if the terminal isn't defined
    NSUInteger windowWidth = MAX(getmaxx(_window) - (ellipsis ? 2 : 1), 0);
    if (windowWidth == 0) {
        return [_output appendString:line];
    }
    
    // Calculate line length without including styled strings as they don't affect the text column width
    __block NSUInteger lineLength = 0;
    
    YDCommandOutputStyleStringEnumerateUsingBlock(line, ^(NSString *substring, YDCommandOutputStyle *style, BOOL *stop) {
        if (style != NULL) {
            // Always append style strings, otherwise our styling will become corrupted
            [self.output appendString:substring];
        } else if (lineLength < windowWidth) {
            // Append text content as long as it fits the window
            NSString *chunk = [substring substringToIndex:MIN(substring.length, windowWidth - lineLength)];
            [self.output appendString:chunk];
            lineLength += chunk.length;
            
            // If our text has been truncated, add an ellipsis
            if (chunk.length < substring.length && ellipsis) {
                [self.output appendString:@"…"];
            }
        }
    });
}

/*! Enumerate lines in a string along with the value which caused the line to break (don't assume \n) */
- (void)_enumerateLinesInString:(NSString *)string usingBlock:(void(^)(NSString *line, NSString *linebreak, BOOL *stop))block {
    NSRange range = NSMakeRange(0, 0);
    BOOL stop = NO;
    
    do {
        NSUInteger lineStart, lineEnd, contentsEnd;
        [string getLineStart:&lineStart end:&lineEnd contentsEnd:&contentsEnd forRange:range];
        
        NSString *line = [string substringWithRange:NSMakeRange(lineStart, contentsEnd - lineStart)];
        NSString *linebreak = [string substringWithRange:NSMakeRange(contentsEnd, lineEnd - contentsEnd)];
        
        block(line, linebreak, &stop);
        
        range.location = lineEnd;
    } while (!stop && range.location < string.length);
}

@end
