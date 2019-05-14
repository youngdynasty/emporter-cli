//
//  EMUtils.h
//  emporter-cli
//
//  Created by Mikey on 24/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "Emporter.h"
#import "YDCommandOutput.h"
#import "YDCommandVariable.h"


NS_ASSUME_NONNULL_BEGIN

#pragma mark - JSON

/*! An error for JSON output */
typedef NSDictionary<NSString*,id> *EMJSONError;

/*! Error codes used for EMJSONError payloads, which mirror standard HTTP status codes for simplicity */
typedef NS_ENUM(NSUInteger, EMJSONErrorCode) {
    EMJSONErrorCodeBadRequest = 400,
    EMJSONErrorCodeUnauthorized = 401,
    EMJSONErrorCodeNotFound = 404,
    EMJSONErrorCodeConflict = 409,
    EMJSONErrorCodeBadGateway = 502,
    EMJSONErrorCodeUnavailable = 503,
    EMJSONErrorCodeInternal = 500
};

/*! Create an error suitable for JSON output */
EMJSONError EMJSONErrorCreate(EMJSONErrorCode code, NSString *message, NSDictionary *__nullable userInfo);

/*! A convenience method to create a JSON error which wraps NSError */
EMJSONError EMJSONErrorCreateInternal(NSString *message, NSError *error);

/*! Create a JSON object for a tunnel and optionally include its state */
NSDictionary* EMJSONObjectForTunnel(EmporterTunnel *tunnel, BOOL includeState);

/*! Create a JSON object for a tunnel's state */
NSDictionary* EMJSONObjectForTunnelState(EmporterTunnel *tunnel);

#pragma mark - Formatting Output

/*! A description for a tunnel's state, suitable for output, with optional styling */
NSString *EMTunnelStateDescription(EmporterTunnel *tunnel, BOOL ascii, YDCommandOutputStyle *__nullable outStyle);

/*! A description of a tunnel's source, suitable for output */
NSString *EMTunnelSourceDescription(EmporterTunnel *tunnel);

/*! A description of the service state, suitable for output, with optional styling */
NSString *EMServiceStateDescription(EmporterServiceState serviceState, BOOL ascii, YDCommandOutputStyle *__nullable outStyle);

/* Output a styled success message */
void EMOutputSuccess(id <YDCommandOutputWriter> output, NSString *format, ...);

/* Output a styled warning message */
void EMOutputWarning(id <YDCommandOutputWriter> output, NSString *format, ...);

/* Output a styled error message */
void EMOutputError(id <YDCommandOutputWriter> output, NSString *format, ...);

#pragma mark - Argument Parsing

/*! An enumeration representing the source of a tunnel */
typedef NS_ENUM(NSUInteger, EMSourceType) {
    /*! Unknown source */
    EMSourceTypeUnknown,
    /*! A directory */
    EMSourceTypeDirectory,
    /*! An ID */
    EMSourceTypeID,
    /*! A local port */
    EMSourceTypePort,
    /*! A local URL */
    EMSourceTypeURL
};

/*! Guess the source type from an input string */
extern EMSourceType EMSourceTypeGuess(NSString *str);

/*! A description of a source type */
extern NSString* EMSourceTypeDescription(EMSourceType type);

/*! A description of a source type using a contextual string */
extern NSString* EMSourceTypeDescriptionFromString(EMSourceType type, NSString *str);

/*! An explicit URL derived from an input string with the given type. If the type is unknown, it will be derived using \c EMSourceTypeGuess. */
extern NSURL* __nullable EMSourceURLFromString(NSString *str, EMSourceType type);

/*! Create a block suitable for use within \c YDCommandVariable for parsing a colon-separated username and password. */
extern YDCommandVariableBlock EMUsernamePasswordBlock(NSString *__strong _Nullable *__nullable outUsername, NSString *__strong _Nullable *__nullable outPassword);

/*! Run a prompt which requires a truthy response (y/n/...) from standard input */
extern BOOL EMRunPrompt(NSString *prompt, BOOL defaultValue);

#pragma mark -

/*! A convenience method which adds an observer to the default NSNotifcationCenter which is removed when the returned object is deallocated */
extern id EMNotificationObserverBlock(NSNotificationName name, id object, void(^block)(NSNotification *note));

/*! Run an event-driven loop which optionally invokes a block each time a source is handled until the SIGINT, SIGTERM, or an explicit call to \c EMBlockRunLoopStop */
extern void EMBlockRunLoopRun(dispatch_block_t __nullable block);

/*! Stop any currently-running invocations of EMBlockRunLoop */
extern void EMBlockRunLoopStop(void);

/*! Find the application which is currently hosting the current process.
 
 The application may not be the direct parent of the process, but rather the first application bundle within the process hierarchy.
 In other words, if an application launches an instance of NodeJS, which then launches this app, the host application will be the app which launched NodeJS.
 */
extern NSRunningApplication *__nullable EMHostApplication(void);

NS_ASSUME_NONNULL_END
