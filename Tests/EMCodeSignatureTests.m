//
//  EMSignedCodeTests.m
//  emporter-cli-tests
//
//  Created by Mike Pulaski on 09/05/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "EMCodeSignature.h"

@interface EMSignedCodeTests : XCTestCase

@end

@implementation EMSignedCodeTests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testAppleSignatures {
    NSError *error = nil;
    EMCodeSignature *notesSignature = [[EMCodeSignature alloc] initWithFileURL:[NSURL fileURLWithPath:@"/Applications/Notes.app"] error:&error];
    XCTAssertNotNil(notesSignature, @"%@", error);
    
    // This isn't very portable, sorry :)
    EMCodeSignature *highSierraNotesSignature = [[EMCodeSignature alloc] initWithFileURL:[NSURL fileURLWithPath:@"/Volumes/High Sierra/Applications/Notes.app"] error:NULL];
    XCTAssertNotNil(highSierraNotesSignature, "%@", error);
    
    XCTAssertEqualObjects(highSierraNotesSignature.teamIdentifier, highSierraNotesSignature.teamIdentifier);
    XCTAssertEqualObjects(highSierraNotesSignature.requirements, highSierraNotesSignature.requirements);
    
    XCTAssertTrue([highSierraNotesSignature matches:notesSignature error:NULL]);
}

- (void)testBadAppId {
    NSError *error = nil;
    EMCodeSignature *notesSignature = [[EMCodeSignature alloc] initWithFileURL:[NSURL fileURLWithPath:@"/Applications/Notes.app"] error:&error];
    XCTAssertNotNil(notesSignature, @"%@", error);
    
    // This isn't very portable for other people... sorry :)
    EMCodeSignature *textEditSignature = [[EMCodeSignature alloc] initWithFileURL:[NSURL fileURLWithPath:@"/Applications/TextEdit.app"] error:NULL];
    XCTAssertNotNil(textEditSignature, "%@", error);
    
    XCTAssertEqualObjects(notesSignature.teamIdentifier, textEditSignature.teamIdentifier);
    XCTAssertFalse([notesSignature matches:textEditSignature error:NULL]);
}

@end
