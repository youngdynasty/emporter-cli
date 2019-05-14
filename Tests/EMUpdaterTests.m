//
//  EMUpdaterTests.m
//  emporter-cli-tests
//
//  Created by Mike Pulaski on 09/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EMUpdater.h"
#import "EMUpdate.h"


@interface EMUpdaterTests : XCTestCase
@end


@implementation EMUpdaterTests

- (void)testDownload {
    NSURL *packageURL = [NSURL URLWithString:@"https://github.com/video-dev/hls.js/archive/v0.12.4.tar.gz"];
    
    XCTestExpectation *updateExpectation = [self expectationWithDescription:@"update"];
    updateExpectation.expectedFulfillmentCount = 3;
    
    NSMutableArray *states = [NSMutableArray array];
    [EMUpdater applyWithURL:packageURL stateHandler:^(EMUpdaterState state, NSProgress *progress, NSError *error) {
        [states addObject:@(state)];
        
        switch (state) {
            case EMUpdaterStateDownloading:
            case EMUpdaterStateExtracting:
                XCTAssertNotNil(progress);
                break;
            case EMUpdaterStateComplete:
                XCTAssertNotNil(error);
                XCTAssertEqualObjects(error.localizedDescription, @"Executable not found in update package");
                break;
            default:
                break;
        }
        
        [updateExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    XCTAssertEqualObjects(states, (@[@(EMUpdaterStateDownloading), @(EMUpdaterStateExtracting), @(EMUpdaterStateComplete)]));
}

- (void)testInvalidBinary {
    NSURL *packageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Data/deflate" withExtension:@"tar.gz"];

    XCTestExpectation *updateExpectation = [self expectationWithDescription:@"update"];
    updateExpectation.expectedFulfillmentCount = 2;
    
    NSMutableArray *states = [NSMutableArray array];
    
    [EMUpdater applyWithURL:packageURL stateHandler:^(EMUpdaterState state, NSProgress *progress, NSError *error) {
        [states addObject:@(state)];
        
        switch (state) {
            case EMUpdaterStateComplete:
                XCTAssertNotNil(error);
                XCTAssertEqualObjects(error.localizedDescription, @"Executable not found in update package");
                break;
            case EMUpdaterStateExtracting:
                XCTAssertNotNil(progress);
                break;
            default:
                break;
        }
        
        [updateExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    XCTAssertEqualObjects(states, (@[@(EMUpdaterStateExtracting), @(EMUpdaterStateComplete)]));
}

- (void)testCancelation {
    NSURL *packageURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Data/deflate" withExtension:@"tar.gz"];
    XCTestExpectation *updateExpectation = [self expectationWithDescription:@"update"];
    updateExpectation.expectedFulfillmentCount = 2;
    
    NSMutableArray *states = [NSMutableArray array];
    
    [EMUpdater applyWithURL:packageURL stateHandler:^(EMUpdaterState state, NSProgress *progress, NSError *error) {
        [states addObject:@(state)];
        
        switch (state) {
            case EMUpdaterStateCanceled:
                XCTAssertNil(error);
                XCTAssertNil(progress);
                break;
            case EMUpdaterStateExtracting:
                [progress cancel];
                break;
            default:
                break;
        }
        
        [updateExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    XCTAssertEqualObjects(states, (@[@(EMUpdaterStateExtracting), @(EMUpdaterStateCanceled)]));
}

@end
