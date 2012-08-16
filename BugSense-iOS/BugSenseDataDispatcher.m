/*
 
 BugSenseDataDispatcher.h
 BugSense-iOS
 
 Copyright (c) 2012 BugSense Inc.
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 Author: Nick Toumpelis, nick@bugsense.com
 Author: John Lianeris, jl@bugsense.com
 
 */

#import "BSAFHTTPRequestOperation.h"
#import "BugSenseCrashController.h"
#import "BSOpenUDID.h"
#import "BugSenseDataDispatcher.h"

#define BUGSENSE_REPORTING_SERVICE_URL          @"http://www.bugsense.com/api/errors"
#define BUGSENSE_REPORTING_SERVICE_SECURE_URL   @"https://www.bugsense.com/api/errors"
#define BUGSENSE_HEADER                         @"X-BugSense-Api-Key"

#define BUGSENSE_ANALYTICS_SERVICE_URL  @"http://ticks.bugsense.com/stream/%@/%@"

#define BUGSENSE_ENTERPRISE_REPORTING_PATH      @"/api/errors"
#define BUGSENSE_ENTERPRISE_ANALYTICS_PATH      @"/api/ticks/%@/%@"

#define kNoJSONGivenErrorMsg            @"BugSense --> No JSON data was given to post!"
#define kServerRespondedMsg             @"BugSense --> Server responded with status code: %i"
#define kErrorMsg                       @"BugSense --> Error: %@"
#define kPostingJSONDataMsg             @"BugSense --> Posting JSON data..."
#define kNoAnalyticsGivenErrorMsg       @"BugSense --> No analytics data was given to post!"
#define kPostingAnalyticsDataMsg        @"BugSense --> Posting analytics data..."


@interface BugSenseCrashController (Delegation)

- (void) operationCompleted:(BOOL)statusCodeAcceptable withData:(NSData *)data;
- (void) analyticsOperationCompleted:(BOOL)statusCodeAcceptable forData:(NSData *)data;

@end

@implementation BugSenseDataDispatcher

+ (BOOL) postJSONData:(NSData *)jsonData withAPIKey:(NSString *)key delegate:(BugSenseCrashController *)delegate showFeedback:(BOOL)feedbackOption{
    if (!jsonData) {
        NSLog(kNoJSONGivenErrorMsg);
        return NO;
    } else {
        
        NSString *reqSysVer = @"4.0";
        NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
        NSURL *bugsenseURL = nil;
        
        BOOL isEnterprise = YES;
        
        if (isEnterprise) {
            bugsenseURL = [NSURL URLWithString:[[BugSenseCrashController endpointURL] stringByAppendingPathComponent:BUGSENSE_ENTERPRISE_REPORTING_PATH]];
        }
        
        if (!bugsenseURL) {
            bugsenseURL = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) ? [NSURL URLWithString:BUGSENSE_REPORTING_SERVICE_SECURE_URL] : [NSURL URLWithString:BUGSENSE_REPORTING_SERVICE_URL];
        }
        
        NSMutableURLRequest *bugsenseRequest = [[[NSMutableURLRequest alloc] initWithURL:bugsenseURL 
            cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f] autorelease];
        [bugsenseRequest setHTTPMethod:@"POST"];
        [bugsenseRequest setValue:key forHTTPHeaderField:BUGSENSE_HEADER];
        [bugsenseRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableData *postData = [NSMutableData data];
        [postData appendData:[@"data=" dataUsingEncoding:NSUTF8StringEncoding]];
        [postData appendData:jsonData];
        [bugsenseRequest setHTTPBody:postData];
        
        BSAFHTTPRequestOperation *operation = [BSAFHTTPRequestOperation operationWithRequest:bugsenseRequest 
            completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error) {
                NSLog(kServerRespondedMsg, response.statusCode);
                if (error) {
                    NSLog(kErrorMsg, error);
                    [delegate operationCompleted:NO withData:nil];
                } else {
                    BOOL statusCodeAcceptable = [[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)] 
                                                                          containsIndex:[response statusCode]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (feedbackOption) {
                            [delegate operationCompleted:statusCodeAcceptable withData:data];
                        } else {
                            [delegate operationCompleted:statusCodeAcceptable withData:nil];
                        }
                    });
                }
        }];
        
        [[NSOperationQueue mainQueue] addOperation:operation];
        
        NSLog(kPostingJSONDataMsg);
        
        return YES;
    }
}

+ (BOOL)postAnalyticsData:(NSData *)analyticsData withAPIKey:(NSString *)key delegate:(BugSenseCrashController *)delegate {
    if (!analyticsData) {
        NSLog(kNoAnalyticsGivenErrorMsg);
        return NO;
    } else {
        NSURL *bugsenseURL = nil;
        
        BOOL isEnterprise = YES;
        
        if (isEnterprise) {
            bugsenseURL = [NSURL URLWithString:[[BugSenseCrashController endpointURL] stringByAppendingPathComponent:[NSString stringWithFormat:BUGSENSE_ENTERPRISE_ANALYTICS_PATH, key, [BSOpenUDID value]]]];
        }
        
        if (!bugsenseURL) {
            bugsenseURL = [NSURL URLWithString:[NSString stringWithFormat:BUGSENSE_ANALYTICS_SERVICE_URL, key, [BSOpenUDID value]]];
        }
        
        NSMutableURLRequest *bugsenseRequest = [[[NSMutableURLRequest alloc] initWithURL:bugsenseURL 
                                                                             cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f] autorelease];
        [bugsenseRequest setHTTPMethod:@"POST"];
        [bugsenseRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        
        NSMutableData *postData = [NSMutableData data];
        [postData appendData:[@"data=" dataUsingEncoding:NSASCIIStringEncoding]];
        [postData appendData:analyticsData];
        [bugsenseRequest setHTTPBody:postData];
        
        BSAFHTTPRequestOperation *operation = [BSAFHTTPRequestOperation operationWithRequest:bugsenseRequest 
            completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error) {
                NSLog(kServerRespondedMsg, response.statusCode);
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [delegate analyticsOperationCompleted:NO forData:analyticsData];
                    });
                } else {
                    BOOL statusCodeAcceptable = [[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)] containsIndex:[response statusCode]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [delegate analyticsOperationCompleted:statusCodeAcceptable forData:analyticsData];
                    });
                }
        }];
        
        [[NSOperationQueue mainQueue] addOperation:operation];
        
        NSLog(kPostingAnalyticsDataMsg);
        
        return YES;
    }
}

@end
