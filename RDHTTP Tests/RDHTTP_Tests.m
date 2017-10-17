//
//  RDHTTPTestsXCT.m
//  RDHTTPTestsXCT
//
//  Created by pastey on 10/7/13.
//  Copyright (c) 2013 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RDHTTP.h"
#import "RDHTTPTestServer.h"


@interface RDHTTPTestsXCT : XCTestCase

@end

@implementation RDHTTPTestsXCT
{
    BOOL operationComplete;
}

- (void)setUp
{
    [super setUp];

    [[RDHTTPTestServer testServer] cleanUp];
    [RDHTTPTestServer.testServer cleanUp];
    RDHTTPTestServer.testServer.enabled = NO;
    [NSURLProtocol registerClass:[RDHTTPTestProtocolHandler class]];
}

- (void)tearDown
{
    [NSURLProtocol unregisterClass:[RDHTTPTestProtocolHandler class]];
    [[RDHTTPTestServer testServer] cleanUp];

    [super tearDown];
}

- (BOOL)waitWithTimeout:(NSTimeInterval)timeout
{
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    while (!operationComplete &&
           [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.05]])
    {
        if ([NSDate timeIntervalSinceReferenceDate] - start > timeout) {
            return NO;
        }
    }
    return YES;
}

- (void)testSimpleHTTPGet {
    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://testserver.objc/"];

    NSString * expectedResponseValue = @"RDHTTP";
    
    RDHTTPTestServer.testServer.expectedResponseData = [expectedResponseValue dataUsingEncoding:NSUTF8StringEncoding];
    RDHTTPTestServer.testServer.enabled = YES;
    

    __block NSString *responseText = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            XCTFail(@"response error %@", response.error);

        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");
    XCTAssertEqualObjects(expectedResponseValue, responseText, @"but it is not");
}

- (void)testHTTPGetUserAgent {
    
    RDHTTPTestServer.testServer.enabled = YES;

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://testserver.objc/"];
    request.userAgent = @"GlokayaKuzdra 1.0/RDHTTP";
    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error != nil) {
            XCTFail(@"response error %@", response.error);
        }

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");

    NSDictionary *headers = RDHTTPTestServer.testServer.receivedHTTPHeaderFields;
    XCTAssertEqualObjects(request.userAgent, [headers objectForKey:@"User-Agent"]);
}

- (void)testSimpleHTTPPost {

    RDHTTPTestServer.testServer.enabled = YES;
    RDHTTPTestServer.testServer.echoPostParameters = YES;

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://testserver.objc/"];
    [[request formPost] setPostValue:@"1" forKey:@"a"];
    [[request formPost] setPostValue:@"2" forKey:@"b"];

    __block NSString *responseText = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            XCTFail(@"response error %@", response.error);

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");
    XCTAssertEqualObjects(responseText, @"a=>1\nb=>2\n", @"but it is not");
}

 - (void)testBasicAuthHTTPGet {
 
     RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://httpbin.org/basic-auth/user/passwd"];
     __block NSString *responseText = nil;
     
     
     [request setHTTPAuthHandler:^(RDHTTPAuthorizer *httpAuthorizer) {
         [httpAuthorizer continueWithUsername:@"user" password:@"passwd"];
     }];

 
     [request startWithCompletionHandler:^(RDHTTPResponse *response) {
         if (response.error == nil) {
             responseText = [response.responseString copy];
         }
         else
             NSLog(@"response error %@", response.error);
 
         operationComplete = YES;
 
     }];
 
     XCTAssertTrue([self waitWithTimeout:5.0], @"wait timeout");
     BOOL ok = responseText && [responseText containsString:@"authenticated"];
     XCTAssertTrue(ok, @"No success indicator in password test");
 }


- (void)testBasicAuthHTTPGetNoBlock {

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://testserver.objc/"];
    RDHTTPTestServer.testServer.enabled = YES;
    
    __block NSString *responseText = nil;

    [request tryBasicHTTPAuthorizationWithUsername:@"test" password:@"test"];

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            NSLog(@"response error %@", response.error);

        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:5.0], @"wait timeout");
    
    NSDictionary *headers = RDHTTPTestServer.testServer.receivedHTTPHeaderFields;
    XCTAssertTrue([[headers objectForKey:@"Authorization"] containsString:@"dGVzdDp0ZXN0"]);
}


//- (void)testBasicAuthHTTPGetFAIL {
//
//    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://httpbin.org/basic-auth/user/passwd"];
//    __block NSString *responseText = nil;
//
//
//    [request setHTTPAuthHandler:^(RDHTTPAuthorizer *httpAuthorizer) {
//        [httpAuthorizer continueWithUsername:@"user" password:@"badpassword"];
//    }];
//
//
//    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
//        if (response.error == nil) {
//            responseText = [response.responseString copy];
//        }
//        else
//            NSLog(@"response error %@", response.error);
//
//        operationComplete = YES;
//
//    }];
//
//
//    XCTAssertTrue([self waitWithTimeout:10.0], @"wait timeout");
//    BOOL ok = responseText && [responseText containsString:@"authenticated"];
//    XCTAssertFalse(ok, @"Success indicator in FAIL password test");
//}

- (void)testNormalHTTPSGet {

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://encrypted.google.com/"];
    __block NSString *responseText = nil;
    __block NSError *error = nil;
    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else {
            error = [response.error copy];
            NSLog(@"response error %@", response.error);
        }

        operationComplete = YES;
    }];


    XCTAssertTrue([self waitWithTimeout:5.0], @"wait timeout");
    XCTAssertTrue(error == nil, @"No error in normal https query");

    [responseText release];
    [error release];
}


- (void)testSelfSignedHTTPSGet {
    
    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://self-signed.badssl.com"];
    __block NSString *responseText = nil;

    [request setSSLCertificateTrustHandler:^(RDHTTPSSLServerTrust *sslTrustQuery) {
        [sslTrustQuery trust];
    }];

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            NSLog(@"response error %@", response.error);

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:5.0], @"wait timeout");
    BOOL ok = [responseText rangeOfString:@"self-signed"].location != NSNotFound;
    XCTAssertTrue(ok, @"No success indicator in password test");

}

/*
 //- (void)testSimpleHTTPPOSTFileUpload {
 //    RDHTTPRequest *request = [RDHTTPRequest postRequestWithURL:@"http://osric.readdle.com/tests/post-file.php"];
 //
 //    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"IMG_0045" ofType:@"jpg"];
 //    NSURL *url = [NSURL fileURLWithPath:path];
 //
 //    [[request formPost] setFile:url forKey:@"file"];
 //
 //    __block NSString *responseText = nil;
 //
 //    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
 //        if (response.error == nil) {
 //            responseText = [response.responseString copy];
 //        }
 //        else
 //            STFail(@"response error %@", response.error);
 //
 //        operationComplete = YES;
 //
 //    }];
 //
 //    XCTAssertTrue([self waitWithTimeout:55.0], @"wait timeout");
 //    XCTAssertEqualObjects(responseText, @"size:33464\nmd5:c9894d80c2d05b826fabe24283031fe6", @"but it is not");
 //}
 */

//- (void)testCancelMethod {
//    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://www.ubuntu.com/start-download?distro=desktop&bits=32&release=latest"];
//
//    __block BOOL isCancelled = NO;
//
//    request.shouldSaveResponseToFile = YES;
//
//    RDHTTPOperation *operation = [request startWithCompletionHandler:^(RDHTTPResponse *response) {
//        XCTFail(@"completion handler called!");
//    }];
//
//    double delayInSeconds = 3.0;
//    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
//    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [operation cancel];
//        NSLog(@"cancel operation");
//        isCancelled = YES;
//        if (operation.isCancelled)
//            operationComplete = YES;
//    });
//
//    XCTAssertTrue([self waitWithTimeout:25.0], @"wait timeout");
//    XCTAssertTrue(isCancelled, @"RDHTTP should be cancelled, but it is not");
//}

/*
 //- (void)testMultipartPOSTFileUpload {
 //    RDHTTPRequest *request = [RDHTTPRequest postRequestWithURL:@"http://osric.readdle.com/tests/post-files-and-fields.php"];
 //
 //    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"IMG_0045" ofType:@"jpg"];
 //    NSURL *url2 = [NSURL fileURLWithPath:path];
 //
 //    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Earphones_UG" ofType:@"pdf"];
 //    NSURL *url1 = [NSURL fileURLWithPath:path];
 //
 //    path = [[NSBundle bundleForClass:[self class]] pathForResource:@"cakephp-cakephp-2.0.3-0-gde5a4ea" ofType:@"zip"];
 //    NSURL *url3 = [NSURL fileURLWithPath:path];
 //
 //
 //    [[request formPost] setFile:url1 forKey:@"file1"];
 //    [[request formPost] setFile:url2 forKey:@"file2"];
 //    [[request formPost] setFile:url3 forKey:@"file3"];
 //
 //    [[request formPost] setPostValue:@"zorro" forKey:@"text1"];
 //    [[request formPost] setPostValue:@"pegasus" forKey:@"text2"];
 //
 //    __block NSString *responseText = nil;
 //
 //    [request setProgressHandler:^(float progress, BOOL upload) {
 //        NSLog(@"%f UPLOAD=%d", progress, upload);
 //    }];
 //
 //    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
 //        if (response.error == nil) {
 //            responseText = [response.responseString copy];
 //        }
 //        else
 //            STFail(@"response error %@", response.error);
 //
 //        operationComplete = YES;
 //
 //    }];
 //
 //    NSMutableString *refString = [NSMutableString stringWithCapacity:1024];
 //    [refString appendString:@"877325/b0d1463be77d15f4e31c22169bda45e2\n"];
 //    [refString appendString:@"33464/c9894d80c2d05b826fabe24283031fe6\n"];
 //    [refString appendString:@"1646835/ecd5e85b41a6c33ecfcc93c0f2c5d421\n"];
 //    [refString appendString:@"zorro/pegasus\n"];
 //
 //    XCTAssertTrue([self waitWithTimeout:55.0], @"wait timeout");
 //    XCTAssertEqualObjects(responseText, refString, @"but it is not");
 //
 //}
 */

- (void)testHTTPGetRedirect {
    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://httpbin.org/redirect-to?url=http%3A%2F%2Fhttpbin.org%2Fuuid"];
    
    request.shouldRedirect = YES;
    
    __block NSString *responseText = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        NSLog(@"response URL %@ ", response.URL);
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            XCTFail(@"response error %@", response.error);

        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");
    XCTAssertTrue([responseText containsString:@"\"uuid\":"]);

    
    [responseText release];
}

- (void)testHTTPGetRedirectNO {
    [RDHTTPTestServer testServer].enabled = NO;

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"https://httpbin.org/redirect-to?url=http%3A%2F%2Fhttpbin.org%2Fuuid"];
    request.shouldRedirect = NO;

    __block NSString *responseText = nil;
    __block NSError *error = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        NSLog(@"response URL %@ ", response.URL);
        responseText = [response.responseString copy];
        error = [response.httpError copy];
        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");
    
    
    NSLog(@"%@", responseText);
    NSLog(@"redirect no = %@", error);


    XCTAssertEqual(302, error.code, @"error code 302 redirect, but it is not");

    [responseText release];
    [error release];
}



- (void)testHTTPRedirectLoop {
    [RDHTTPTestServer testServer].enabled = NO;

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://osric.readdle.com/tests/redirect-loop1.php"];

    __block NSString *responseText = nil;
    __block NSError *error = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        responseText = [response.responseString copy];
        error = [response.error copy];
        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");

    NSLog(@"redirect loop error: %@", error);

    XCTAssertTrue(error != nil, @"redirect loop error, but it is not");

    [responseText release];
    [error release];
}

- (void)testHTTPRedirectPost2616 {
    [RDHTTPTestServer testServer].enabled = NO;

    RDHTTPRequest *request = [RDHTTPRequest postRequestWithURLString:@"https://httpbin.org/redirect-to?url=http%3A%2F%2Fhttpbin.org%2Fpost"];
    
    request.shouldUseRFC2616RedirectBehaviour = YES;

    NSString *specialFieldName = @"rdhttp_specialPostField";
    [[request formPost] setPostValue:@"1" forKey:specialFieldName];

    __block NSString *responseText = nil;

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error == nil) {
            responseText = [response.responseString copy];
        }
        else
            XCTFail(@"response error %@", response.error);

        operationComplete = YES;

    }];

    XCTAssertTrue([self waitWithTimeout:5.0], @"wait timeout");
    XCTAssertTrue([responseText containsString:specialFieldName], "proper post body");
}

- (void) testStandardCookiesStorage {

    // pastey:
    // I've found interesting piculiarity about testing Standard cookies storage with overwritten HTTP protocol handler -
    // standard cookies storage does not work in such case.
    // As far as I understood looking at objective c message calls traces,
    // in case of not overwritten HTTP protocol, cookies storage gets filled in a separate
    // process - the one executing NSURLSessions. By the way, NSURLRequest, at iOS 7, works over NSURLSession
    //

    [RDHTTPTestServer testServer].enabled = NO;

    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    for (NSHTTPCookie *c in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:c];
    }
    
    NSURL *url = [NSURL URLWithString:@"http://httpbin.org/cookies/set?k2=v2&k1=v1"];
    XCTAssertEqual(0u, [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url].count);

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:url.absoluteString];
    XCTAssertTrue([request HTTPShouldHandleCookies]);

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error != nil) {
            XCTFail(@"response error %@", response.error);
        }

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");

    XCTAssertTrue([[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url].count >= 1u);
}

- (void) testCustomCookiesStorage {
    RDHTTPTestServer.testServer.enabled = YES;
    
    // catch cookie from server
    RDHTTPCookiesStorage * cookiesStorage = [[RDHTTPCookiesStorage new] autorelease];
    XCTAssertEqual(0u, [cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://example.com"]].count);

    RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://example.com/test.html"];
    [request setCustomCookiesStorage:cookiesStorage];

    [[RDHTTPTestServer testServer] setExpectedResponseHeaders:@{ @"Set-Cookie" : @"name=value;" }];
    
    //RDHTTPTestServer.testServer.

    [request startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error != nil) {
            XCTFail(@"response error %@", response.error);
        }

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");

    XCTAssertEqual(1u, [cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://example.com"]].count);

    // send it back

    RDHTTPRequest *anotherRequest = [RDHTTPRequest getRequestWithURLString:@"http://example.com/test.html"];
    [anotherRequest setCustomCookiesStorage:cookiesStorage];

    [[RDHTTPTestServer testServer] setExpectedResponseHeaders:nil];

    operationComplete = NO;
    [anotherRequest startWithCompletionHandler:^(RDHTTPResponse *response) {
        if (response.error != nil) {
            XCTFail(@"response error %@", response.error);
        }

        operationComplete = YES;
    }];

    XCTAssertTrue([self waitWithTimeout:15.0], @"wait timeout");

    XCTAssertTrue([[[[RDHTTPTestServer testServer] receivedHTTPHeaderFields] valueForKey:@"Cookie"] isEqualToString:@"name=value"]);
}


@end
