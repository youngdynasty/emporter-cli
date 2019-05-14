//
//  EMUpdateFeedTests.m
//  emporter-cli-tests
//
//  Created by Mike Pulaski on 08/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EMUpdateFeed.h"

@interface EMUpdateFeedTests : XCTestCase

@end

@implementation EMUpdateFeedTests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testGitHubReleaseFeed {
    NSURL *feedURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Data/GitHub/libvips" withExtension:@"json"];
    EMUpdateFeed *feed = [[EMUpdateFeed alloc] initWithURL:feedURL type:EMUpdateTypeGitHubRelease];
    
    XCTestExpectation *readExpectation = [self expectationWithDescription:@"read"];
    
    [feed readFeedWithCompletionHandler:^(NSArray<EMUpdate *> *updates, NSError *error) {
        XCTAssertNotNil(updates, @"%@", error);
        XCTAssertEqual(updates.count, 29);
        
        EMUpdate *latest = updates.firstObject;
        XCTAssertTrue(EMVersionEquals(latest.version, (EMVersion){8, 8, 0, "rc2"}), @"%@", EMVersionDescription(latest.version));
        XCTAssertEqualObjects(latest.title, @"v8.8.0-rc2");
        XCTAssertEqualObjects(latest.body, @"As rc1, but incorporating a few more fixes:\r\n\r\n- in/out/dest-in/dest-out compositing modes improved\r\n- better handling of inverted cmyk jpg\r\n- better handling of iterations in animation save via ImageMagick\r\n- improved thumbnailing of multi-page documents\r\n- better animated webp thumbnailing\r\n- much better Windows binary\r\n");
        XCTAssertEqualObjects(latest.publishDate, [NSDate dateWithTimeIntervalSince1970:1557343267]);
        XCTAssertEqualObjects(latest.assetURLs, (@[
                                                  [NSURL URLWithString:@"https://github.com/libvips/libvips/releases/download/v8.8.0-rc2/vips-8.8.0-rc2.tar.gz"],
                                                  [NSURL URLWithString:@"https://github.com/libvips/libvips/releases/download/v8.8.0-rc2/vips-dev-w64-all-8.8.0-rc2.zip"],
                                                  [NSURL URLWithString:@"https://github.com/libvips/libvips/releases/download/v8.8.0-rc2/vips-dev-w64-web-8.8.0-rc2.zip"]
                                                ]));
        
        [readExpectation fulfill];
    }];
    
    [self waitForExpectations:@[readExpectation] timeout:2];
}

@end
