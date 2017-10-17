//
//  RDHTTPTestServer.m
//  RDHTTP Tests
//
//  Created by Andrian Budantsov on 10/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import "RDHTTPTestServer.h"


@implementation RDHTTPTestServer
{
    NSInteger       _statusCode;
    NSDictionary    * _headers;
    NSData          * _responseData;
    NSDictionary    * _receivedHTTPHeaderFields;
    BOOL            _enabled;
}

+ (RDHTTPTestServer*) testServer {
    static RDHTTPTestServer * _instance;
    if (nil == _instance) {
        _instance = [RDHTTPTestServer new];
    }
    return _instance;
}

- (void) setExpectedResponseCode:(NSInteger)statusCode {
    _statusCode = statusCode;
}

- (NSInteger)statusCode {
    return _statusCode;
}

- (void)setExpectedResponseHeaders:(NSDictionary*)expectedHeaders {
    [_headers autorelease];
    _headers = [expectedHeaders copy];
}

- (NSDictionary *)expectedResponseHeaders {
    return _headers;
}

- (void)setExpectedResponseData:(NSData *) responseData {
    [_responseData autorelease];
    _responseData = [responseData copy];
}

- (NSData *)expectedResponseData {
    return _responseData;
}

- (void) setReceivedHTTPHeaderFields:(NSDictionary*) receivedHTTPHeaderFields {
    [_receivedHTTPHeaderFields autorelease];
    _receivedHTTPHeaderFields = [receivedHTTPHeaderFields copy];
}

- (NSDictionary*) receivedHTTPHeaderFields {
    return _receivedHTTPHeaderFields;
}

- (id) init {
    self = [super init];
    if (self) {
        _enabled = YES;
        [self cleanUp];
    }
    return self;
}

- (void) cleanUp {
    _statusCode = 200;
    [_headers release];
    _headers = nil;
    [_responseData release];
    _responseData = [[@"" dataUsingEncoding:NSUTF8StringEncoding] retain];
    [_receivedHTTPHeaderFields release];
    _receivedHTTPHeaderFields = nil;
    self.echoPostParameters = NO;
}

- (void)dealloc
{
    [self cleanUp];
    [super dealloc];
}

@end

@implementation RDHTTPTestProtocolHandler

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (NO == [RDHTTPTestServer testServer].enabled) {
        return NO;
    }
    
    return [[[request URL] scheme] isEqualToString:@"http"];
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client {
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    if (self) {
        
    }
    return self;
}

- (void)startLoading {
    
    [[RDHTTPTestServer testServer] setReceivedHTTPHeaderFields:[self.request allHTTPHeaderFields]];
    
    if(1/*gILCannedResponseData*/) {
        NSHTTPURLResponse *response =
        [[NSHTTPURLResponse alloc] initWithURL:[self.request URL]
                                    statusCode:[[RDHTTPTestServer testServer] statusCode]
                                   HTTPVersion:@"1.0"
                                  headerFields:@{ @"Set-Cookie" : @"name=value;" }];
        
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        if ([RDHTTPTestServer testServer].echoPostParameters) {
            
            NSString * formPost = [[[NSString alloc] initWithData:(NSData*)[self.request HTTPBody] encoding:NSUTF8StringEncoding] autorelease];
            NSArray * kvs = [formPost componentsSeparatedByString:@"&"];
            NSMutableString * echo = [[NSMutableString new] autorelease];
            for (NSString * kv in kvs) {
                NSArray * components = [kv componentsSeparatedByString:@"="];
                [echo appendString:components[0]];
                [echo appendString:@"=>"];
                [echo appendString:components[1]];
                [echo appendString:@"\n"];
            }
            
            [self.client URLProtocol:self didLoadData:[echo dataUsingEncoding:NSUTF8StringEncoding]];
        }
        else {
            NSData *data = RDHTTPTestServer.testServer.expectedResponseData;
            [self.client URLProtocol:self didLoadData:data];
        }
        [self.client URLProtocolDidFinishLoading:self];
        
        [response release];
    }
    //    else if(gILCannedError) {
    //        [client URLProtocol:self didFailWithError:gILCannedError];
    //    }
}

- (void)stopLoading {
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

@end
