//
//  RDHTTPTestServer.h
//  RDHTTP Tests
//
//  Created by Andrian Budantsov on 10/17/17.
//  Copyright © 2017 Readdle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RDHTTPTestServer : NSURLProtocol
@property (nonatomic, readonly, class)  RDHTTPTestServer *testServer;
@property (nonatomic, assign) BOOL      echoPostParameters;
@property (nonatomic, assign) BOOL      enabled;
@property (nonatomic, copy)   NSData    *expectedResponseData;
- (NSDictionary *)expectedResponseHeaders;
- (void)setExpectedResponseHeaders:(NSDictionary *)expectedHeaders;

- (void)setReceivedHTTPHeaderFields:(NSDictionary *)receivedHTTPHeaderFields;
- (NSDictionary *)receivedHTTPHeaderFields;


- (void)cleanUp;
@end


@interface RDHTTPTestProtocolHandler : NSURLProtocol
@end
