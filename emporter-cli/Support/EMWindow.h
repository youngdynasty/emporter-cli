//
//  EMWindow.h
//  emporter-cli
//
//  Created by Mikey on 28/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YDCommandOutput.h"

NS_ASSUME_NONNULL_BEGIN

@protocol EMWindowWriter;
typedef void(^EMWindowWriterBlock)(id <EMWindowWriter> output);


/*! EMWindow defines a simple window which can be presented in the terminal. */
@interface EMWindow : NSObject

/*! An optional title string to be displayed in the top of the window */
@property(nonatomic) NSString *__nullable title;

/*! An optional status string to be displayed at the bottom of the window */
@property(nonatomic) NSString *__nullable status;

/*! Draw a border for the window */
@property(nonatomic) BOOL drawsBorder;

/*!
 Run the main draw loop.
 
 The block will be invoked immediately when this method is first called. Afterwards, the block will only be invoked when something
 changes, which can be signaled by calling \c setNeedsDisplay or changing any of the properties of the window which might require a redraw
 (such as its title).
 
 This method will not return until until the window is closed (via \c close) or the user requests termination (SIGINT/SIGTERM via ctrl+C).
 
 Although this method will block, it is done in a way such that events will continue to be dispatched to your application. In other words,
 you will still receive notifications (KVO or otherwise) in addition to delegate callbacks while this method is running.
 
 \param block The block used to write contents to the window
 */
- (void)runDrawLoopWithBlock:(EMWindowWriterBlock)block;

/*! Invoke this method to cause the window to redraw. */
- (void)setNeedsDisplay;

/*! Close the window */
- (void)close;

/*! True if the drawing run loop exited because the window was closed */
@property(nonatomic,readonly) BOOL isClosed;

/*! True if the drawing run loop exited because of SIGINT or SIGTERM.*/
@property(nonatomic,readonly) BOOL isTerminated;

@end


/*! Write output to the window */
@protocol EMWindowWriter <YDCommandOutputWriter>

/*! Truncate contents to fit the window's current width within a block */
- (void)applyTruncationWithinBlock:(YDCommandOutputWriterBlock)block;

/*! Text alignment within a window */
typedef NS_ENUM(uint8, EMWindowTextAlignment) {
    EMWindowTextAlignmentLeft,
    EMWindowTextAlignmentCenter,
    EMWindowTextAlignmentRight
};

/*! Align text horizontally in the window within a block */
- (void)applyAlignment:(EMWindowTextAlignment)alignment withinBlock:(YDCommandOutputWriterBlock)block;

@end

NS_ASSUME_NONNULL_END
