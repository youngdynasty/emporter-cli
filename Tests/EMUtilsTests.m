//
//  EMGetCommandTests.m
//  emporter-cli-tests
//
//  Created by Mikey on 24/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EMUtils.h"

@interface EMUtilsTests : XCTestCase

@end

@implementation EMUtilsTests

- (void)testGuessFormat {
    [@{
       @"2FD9C06C-2D12-40F3-B209-0F78DCF69E41": @(EMSourceTypeID),
       @"1234": @(EMSourceTypePort),
       @"~/": @(EMSourceTypeDirectory),
       @"/Library": @(EMSourceTypeDirectory),
       @"localhost": @(EMSourceTypeURL),
       @"mikey.local": @(EMSourceTypeURL),
       @"pow.dev": @(EMSourceTypeURL),
       @"127.0.0.1": @(EMSourceTypeURL),
       @"everythingelse": @(EMSourceTypeDirectory),
    } enumerateKeysAndObjectsUsingBlock:^(NSString *s, NSNumber *exp, BOOL * stop) {
        EMSourceType actual = EMSourceTypeGuess(s);
        EMSourceType expected = [exp integerValue];
        
        XCTAssertEqualObjects(EMSourceTypeDescription(actual), EMSourceTypeDescription(expected), "%@", s);
    }];
}

@end
