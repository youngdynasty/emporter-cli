//
//  EMSpinner.h
//  emporter-cli
//
//  Created by Mike Pulaski on 09/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class YDCommandOutput;
@protocol YDCommandOutputWriter;

/*! An thread-safe ascii spinner */
@interface EMSpinner : NSObject

/*! The designated initializer.
 \param output The destination
 \returns An instance of \c EMSpinner.
 */
- (instancetype)initWithOutput:(YDCommandOutput *)output NS_DESIGNATED_INITIALIZER;

/*! The destination for drawing the spinner */
@property(nonatomic,readonly) YDCommandOutput *output;

/*! An optional message to show alongside the spinner. Can be updated when the spinner is active. */
@property(nonatomic) NSString *__nullable message;

/*! Returns YES if the receiver is spinning */
@property(nonatomic,readonly) BOOL isSpinning;

/*! Start spinning */
- (void)startSpinning;

/*! Stop spinning and optionally clear the line used to display the spinner's contents */
- (void)stopSpinning:(BOOL)resetLine;

@end

NS_ASSUME_NONNULL_END
