//
//  RDHTTP.m
//
//  Copyright (c) 2011, Andrian Budantsov. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this 
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation 
//  and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
//           SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import "RDHTTP.h"
#import "pthread.h"
#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

BOOL RDHTTPUseCredentialPersistenceNone = NO;

NSString *const RDHTTPResponseCodeErrorDomain = @"RDHTTPResponseCodeErrorDomain";
static char *const RDHTTPDispatchQueueActive = "RDHTTPDispatchQueueKey";

#pragma mark - RDHTTP Private API 

@interface RDHTTPRequest(RDHTTPPrivate)
- (NSURLRequest *)_nsurlrequest;
@end

@interface RDHTTPFormPost(RDHTTPPrivate) 
- (NSInputStream *)setupPostFormRequest:(NSMutableURLRequest *)request encoding:(NSStringEncoding)encoding;
@end

@interface RDHTTPOperation(RDHTTPPrivate)
- (id)initWithRequest:(RDHTTPRequest *)aRequest;
@end





#pragma mark - RDHTTPResponse


@interface RDHTTPResponse() {
    NSHTTPURLResponse   *response;
    RDHTTPRequest       *request; // this object is mutable, we agreed to use it only for non-mutable tasks here
    
    NSError             *error;
    NSError             *httpError;
    NSURL               *responseFileURL;
    NSData              *responseData;
    NSString            *responseTextCached;
    
    NSMutableDictionary *allHeaderFieldsLowercase;
}

- (id)initWithResponse:(NSHTTPURLResponse *)response 
               request:(RDHTTPRequest *)request
                 error:(NSError *)error
          tempFilePath:(NSString *)tempFilePath
                  data:(NSData *)responseData;

- (void)setupAllHeaderFieldsLowercaseIfNecessary;

@end

@implementation RDHTTPResponse
@synthesize error;
@synthesize userInfo;
@synthesize responseData;
@synthesize responseFileURL;

- (id)initWithResponse:(NSHTTPURLResponse *)aResponse 
               request:(RDHTTPRequest *)aRequest
                 error:(NSError *)anError
          tempFilePath:(NSString *)aTempFilePath
                  data:(NSData *)aResponseData 
{
    self = [super init];
    if (self) {
        request = [aRequest retain];
        response = [aResponse retain];
        error = [anError retain];
        if (aTempFilePath) 
            responseFileURL = [[NSURL fileURLWithPath:aTempFilePath] retain];
        responseData = [aResponseData retain];
    }
    return self;
}

- (void)dealloc {
    [request release];
    [response release];
    
    [error release];
    [responseFileURL release];
    [responseData release];
    
    [httpError release];
    [responseTextCached release];
    
    [allHeaderFieldsLowercase release];
    [super dealloc];
}

- (NSError *)httpError {
    if (httpError) {
        return httpError;
    }
    
    if (nil == response) {
        return nil;
    }
    NSInteger statusCode = [response statusCode];
    
    if (statusCode >= 200 && statusCode < 300) {
        return nil;
    }
    
    httpError = [[NSError errorWithDomain:RDHTTPResponseCodeErrorDomain code:statusCode userInfo:nil] retain];
    return httpError;
}

- (NSError *)networkError {
    return error;
}

- (NSError *)error {
    if (error) 
        return error;
    
    if (self.httpError)
        return self.httpError;
    
    return nil;
}

- (NSURL *)URL  {
    return response.URL;
}

- (NSUInteger)statusCode {
    return response.statusCode;
}

- (NSDictionary *)allHeaderFields {
    [self setupAllHeaderFieldsLowercaseIfNecessary];
    return allHeaderFieldsLowercase;
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field {
    field = field.lowercaseString;
    [self setupAllHeaderFieldsLowercaseIfNecessary];
    return (NSString *)[allHeaderFieldsLowercase objectForKey:field];
}

- (void)setupAllHeaderFieldsLowercaseIfNecessary {
    if (allHeaderFieldsLowercase == nil) {
        allHeaderFieldsLowercase = [NSMutableDictionary new];
        for (NSString* headerField in response.allHeaderFields.allKeys) {
            NSString* valueForHeaderField = [response.allHeaderFields objectForKey:headerField];
            NSString* lowercaseHeaderField = headerField.lowercaseString;
            
            [allHeaderFieldsLowercase setObject:valueForHeaderField forKey:lowercaseHeaderField];
        }
    }
}

- (NSData *)responseData {
    if (responseData == nil && responseFileURL) {
        NSLog(@"RDHTTP: attempt to access responseData with saveResponseToFile=YES set in request. return nil");
        return nil;
    }
    return responseData;
}

- (NSString *)suggestedFilename {
    return response.suggestedFilename;
}

- (long long)expectedContentLength {
    return [response expectedContentLength];
}

- (NSString *)responseString {
    if (responseData == nil && responseFileURL) {
        NSLog(@"RDHTTP: attempt to access responseText with saveResponseToFile=YES set in request. return nil");
        return nil;
    }
    
    NSStringEncoding encoding = NSUTF8StringEncoding; // default 
    if (response.textEncodingName) {
        encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)response.textEncodingName));
    }
    
    if (responseTextCached == nil && responseData)
        responseTextCached = [[NSString alloc] initWithData:responseData encoding:encoding];
    
    if (responseTextCached == nil && responseData) {
        if (encoding != NSUTF8StringEncoding) 
            NSLog(@"RDHTTP: warning, unable to create string with %@ encoding. Use responseData.", response.textEncodingName);
        else
            NSLog(@"RDHTTP: warning, unable to create string with UTF-8 encoding. Use responseData.");
    }
    
    return responseTextCached;
}

- (NSDictionary *)userInfo {
    return request.userInfo;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDHTTPResponse: URL %@ code %ld length:%lud>", 
            response.URL,
            (long)response.statusCode,
            (unsigned long)[responseData length]];
}

- (BOOL)  moveResponseFileToURL:(NSURL *)destination 
    withIntermediateDirectories:(BOOL)createIntermediates 
                          error:(NSError **)anError
{
    if (createIntermediates) {
        if ([[NSFileManager defaultManager] createDirectoryAtPath:[[destination path] stringByDeletingLastPathComponent]
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:anError] == NO)
            return NO;
    }
    return [[NSFileManager defaultManager] moveItemAtURL:responseFileURL 
                                                   toURL:destination
                                                   error:anError];
}



@end

#pragma mark - RDHTTPRequest

@interface RDHTTPRequest() {
    NSMutableURLRequest *urlRequest;
    rdhttp_block_t      completionBlock;
    NSString            *postBodyFilePath;
    RDHTTPCookiesStorage* _customCookiesStorage;
    BOOL                  _HTTPShouldHandleCookies;
}
- (id)initWithMethod:(NSString *)aMethod resource:(NSObject *)urlObject;
- (void)prepare;
- (rdhttp_block_t)completionBlock;
- (NSString *)base64encodeString:(NSString *)string;
- (NSInputStream *)regenerateBodyStream;

@property(nonatomic, retain) NSString *postBodyFilePath;
@end


@implementation RDHTTPRequest
@synthesize userInfo;
@synthesize dispatchQueue;
@synthesize formPost;
@synthesize shouldSaveResponseToFile;
@synthesize encoding;
@synthesize shouldRedirect;
@synthesize shouldUseRFC2616RedirectBehaviour;
@synthesize shouldReplaceHTTPHeaderFieldsOnRFC2616RedirectBehaviour;
@synthesize useInternalThread;
@synthesize postBodyFilePath;

- (id)initWithMethod:(NSString *)aMethod resource:(NSObject *)urlObject {
    self = [super init];
    if (self) {
        NSURL *url = nil;
        if ([urlObject isKindOfClass:[NSURL class]])
            url = (NSURL *)urlObject;
        else if ([urlObject isKindOfClass:[NSString class]]) {
            url = [NSURL URLWithString:(NSString *)urlObject];
        }
        else {
            if (urlObject == nil)
                NSLog(@"RDHTTP: nil object passed as an URL");
            else
                NSLog(@"RDHTTP: unknown object passed as an URL, should be NSURL or NSString");
            [self release];
            return nil;
        }
        
        urlRequest = [[NSMutableURLRequest requestWithURL:url] retain];
        urlRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
        if (aMethod)
            [urlRequest setHTTPMethod:aMethod];

        self.dispatchQueue = dispatch_get_main_queue();
        encoding = NSUTF8StringEncoding;
        shouldRedirect = YES;
        urlRequest.timeoutInterval = 20;
        useInternalThread = YES;
        _HTTPShouldHandleCookies = YES;
    }
    return self;
}

- (void)dealloc {
    [urlRequest release];
    self.postBodyFilePath = nil;
    self.dispatchQueue = nil;
    self.userInfo = nil;
    self.formPost = nil;
    if (completionBlock) {
        Block_release(completionBlock);
        completionBlock = nil;
    }
    if (headersHandler) {
        Block_release(headersHandler);
        headersHandler = nil;
    }
    if (downloadProgressHandler) {
        Block_release(downloadProgressHandler);
        downloadProgressHandler = nil;
    }
    if (uploadProgressHandler) {
        Block_release(uploadProgressHandler);
        uploadProgressHandler = nil;
    }
    if (SSLCertificateTrustHandler) {
        Block_release(SSLCertificateTrustHandler);
        SSLCertificateTrustHandler = nil;
    }
    if (HTTPAuthHandler) {
        Block_release(HTTPAuthHandler);
        HTTPAuthHandler = nil;
    }
    if (HTTPBodyStreamCreationBlock) {
        Block_release(HTTPBodyStreamCreationBlock);
        HTTPBodyStreamCreationBlock = nil;
    }
    if (responseDataHandler) {
        Block_release(responseDataHandler);
        responseDataHandler = nil;
    }
    [_customCookiesStorage release];
    _customCookiesStorage = nil;
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    RDHTTPRequest *request = [[RDHTTPRequest alloc] init];
    
    request->urlRequest = [urlRequest copyWithZone:zone];
    if (completionBlock)
        request->completionBlock = Block_copy(completionBlock);
    
    request.encoding = self.encoding;
    request.dispatchQueue = self.dispatchQueue;

    // don't use self.formPost here, because it will just create new formPost
    // in case we don't have any 
    RDHTTPFormPost *formPostCopy = [formPost copyWithZone:zone];
    request.formPost = formPostCopy;
    [formPostCopy release];
    
    NSDictionary *userInfoCopy = [userInfo copyWithZone:zone];
    request.userInfo = userInfoCopy;
    [userInfoCopy release];
    request.shouldSaveResponseToFile = shouldSaveResponseToFile;
    request.shouldRedirect = shouldRedirect;
    request.shouldUseRFC2616RedirectBehaviour = shouldUseRFC2616RedirectBehaviour;
    request.shouldReplaceHTTPHeaderFieldsOnRFC2616RedirectBehaviour = shouldReplaceHTTPHeaderFieldsOnRFC2616RedirectBehaviour;
    request.useInternalThread = useInternalThread;
    
    [request setHTTPBodyStreamCreationBlock:self.HTTPBodyStreamCreationBlock];
    [request setSSLCertificateTrustHandler:self.SSLCertificateTrustHandler];
    [request setHTTPAuthHandler:self.HTTPAuthHandler];
    [request setDownloadProgressHandler:self.downloadProgressHandler];
    [request setUploadProgressHandler:self.uploadProgressHandler];
    [request setHeadersHandler:self.headersHandler];
    [request setResponseDataHandler:self.responseDataHandler];
    request.postBodyFilePath = self.postBodyFilePath;

    [request setHTTPShouldHandleCookies:_HTTPShouldHandleCookies];
    [request setCustomCookiesStorage:_customCookiesStorage];
    
    return request;
}

- (NSURLRequest *)_nsurlrequest {
    return urlRequest;
}

+ (id)getRequestWithURL:(NSURL *)url {
    return [self customRequest:@"GET" withURL:url];
}

+ (id)getRequestWithURLString:(NSString *)urlString {
    return [self customRequest:@"GET" withURLString:urlString];
}

+ (id)postRequestWithURL:(NSURL *)url {
    return [self customRequest:@"POST" withURL:url];
}

+ (id)postRequestWithURLString:(NSString *)urlString {
    return [self customRequest:@"POST" withURLString:urlString];
}

+ (id)customRequest:(NSString *)method withURL:(NSURL *)url {
    return [[[self alloc] initWithMethod:method resource:url] autorelease];
}

+ (id)customRequest:(NSString *)method withURLString:(NSString *)urlString {
    return [[[self alloc] initWithMethod:method resource:urlString] autorelease];
}

- (NSDictionary *)allHTTPHeaderFields {
    return [urlRequest allHTTPHeaderFields];
}

- (NSString*)valueForHTTPHeaderField:(NSString*)field {
    return [urlRequest valueForHTTPHeaderField:field];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [urlRequest setValue:value forHTTPHeaderField:field];
}

- (void)tryBasicHTTPAuthorizationWithUsername:(NSString *)username password:(NSString *)password {
    NSString *authString = [NSString stringWithFormat:@"%@:%@", username, password];
    NSString *headerValue = [NSString stringWithFormat:@"Basic %@", [self base64encodeString:authString]];
    [self setValue:headerValue forHTTPHeaderField:@"Authorization"];
}

- (void)postBodyCheckAndSetContentType:(NSString *)contentType {
    if ([urlRequest.HTTPMethod isEqualToString:@"GET"]) {
        NSLog(@"RDHTTP: trying to set post body for GET request");
    }
    
    if (formPost) {
        NSLog(@"RDHTTP: trying to assign postBody with postFiles / multipartPostFiles set");
        NSLog(@"RDHTTP: postFields / multipartPostFiles reset");
        self.formPost = nil;
    }   
    
    if (contentType) {
        [urlRequest setValue:contentType forHTTPHeaderField:@"Content-Type"];
    }
}

- (void)setHTTPBodyStream:(NSInputStream *)inputStream contentType:(NSString *)contentType {
    [self postBodyCheckAndSetContentType:contentType];
    [urlRequest setHTTPBodyStream:inputStream];
}

- (void)setHTTPBodyData:(NSData *)data contentType:(NSString *)contentType {
    [self postBodyCheckAndSetContentType:contentType];
    [urlRequest setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[data length]] forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:data];
}

- (void)setHTTPBodyFilePath:(NSString *)filePath guessContentType:(BOOL)guess {
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO) {
        NSLog(@"RDHTTP: not-existing file %@ in setHTTPBodyFilePath", filePath);
        return;
    }

    NSString *contentType = nil;
    if (guess) {
        contentType = [RDHTTPFormPost guessContentTypeForURL:[NSURL fileURLWithPath:filePath] 
                                             defaultEncoding:encoding];
    }

    
    NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    unsigned long long size = [fileAttrs fileSize];
    [self setValue:[NSString stringWithFormat:@"%llu", size] forHTTPHeaderField:@"Content-Length"];
    [self setHTTPBodyStream:[NSInputStream inputStreamWithFileAtPath:filePath] contentType:contentType];
    
    self.postBodyFilePath = filePath;
}

- (RDHTTPFormPost *)formPost {
    if ([urlRequest.HTTPMethod isEqualToString:@"GET"]) {
        NSLog(@"RDHTTP: warning using formPost with GET HTTP request");
    }
    if (formPost == nil) {
        formPost = [RDHTTPFormPost new];
    }
    return formPost;
}

- (void)setDispatchQueue:(dispatch_queue_t)aDispatchQueue {
    if (dispatchQueue == aDispatchQueue)
        return;
    
    if (dispatchQueue) 
        dispatch_release(dispatchQueue);
    
    if (aDispatchQueue == nil) {
        dispatchQueue = NULL;
        return;
    }
    
    dispatch_retain(aDispatchQueue);
    dispatchQueue = aDispatchQueue;
}

- (rdhttp_block_t)completionBlock {
    return completionBlock;
}

- (RDHTTPOperation *)operationWithCompletionHandler:(rdhttp_block_t)aCompletionBlock {
    if (aCompletionBlock) {
        if (completionBlock) {
            Block_release(completionBlock);
        }
        completionBlock = Block_copy(aCompletionBlock);
    }
    
    RDHTTPOperation *conn = [[RDHTTPOperation alloc] initWithRequest:self];
    return [conn autorelease];
    
}


- (RDHTTPOperation *)startWithCompletionHandler:(rdhttp_block_t)aCompletionBlock {
    RDHTTPOperation *conn = [self operationWithCompletionHandler:aCompletionBlock];
    [conn start];
    return conn;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<RDHTTPRequest: %@ %@>", urlRequest.HTTPMethod, urlRequest.URL];
}

#pragma mark - properties 
@synthesize headersHandler;
@synthesize downloadProgressHandler;
@synthesize uploadProgressHandler;
@synthesize SSLCertificateTrustHandler;
@synthesize HTTPAuthHandler;
@synthesize HTTPBodyStreamCreationBlock;
@synthesize responseDataHandler;

- (void)setURL:(NSURL *)URL {
    [urlRequest setURL:URL];
}

- (NSURL *)URL {
    return [urlRequest URL];
}

- (void)setCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
    [urlRequest setCachePolicy:cachePolicy];
}

- (NSURLRequestCachePolicy)cachePolicy {
    return [urlRequest cachePolicy];
}

- (void)setNetworkServiceType:(NSURLRequestNetworkServiceType)networkServiceType {
    [urlRequest setNetworkServiceType:networkServiceType];
}

- (NSURLRequestNetworkServiceType)networkServiceType {
    return [urlRequest networkServiceType];
}

- (void)setHTTPShouldHandleCookies:(BOOL)HTTPShouldHandleCookies {
    _HTTPShouldHandleCookies = HTTPShouldHandleCookies;
    [urlRequest setHTTPShouldHandleCookies:HTTPShouldHandleCookies];
}

- (BOOL)HTTPShouldHandleCookies {
    return _HTTPShouldHandleCookies;
}

- (void) setCustomCookiesStorage:(RDHTTPCookiesStorage *)customCookiesStorage {
    [_customCookiesStorage autorelease];
    _customCookiesStorage = [customCookiesStorage retain];

    if (_customCookiesStorage) {
        [urlRequest setHTTPShouldHandleCookies:NO];
    }
    else {
        [urlRequest setHTTPShouldHandleCookies:_HTTPShouldHandleCookies];
    }
}

- (RDHTTPCookiesStorage*) customCookiesStorage {
    return _customCookiesStorage;
}

- (void)setHTTPShouldUsePipelining:(BOOL)HTTPShouldUsePipelining {
    [urlRequest setHTTPShouldUsePipelining:HTTPShouldUsePipelining];
}

- (BOOL)HTTPShouldUsePipelining {
    return [urlRequest HTTPShouldUsePipelining];
}


- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval {
    [urlRequest setTimeoutInterval:timeoutInterval];
}

- (NSTimeInterval)timeoutInterval {
    return urlRequest.timeoutInterval;
}


- (void)setUserAgent:(NSString *)userAgent {
    [urlRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
}

- (NSString *)userAgent {
    return [urlRequest valueForHTTPHeaderField:@"User-Agent"];
}

#pragma mark - internal

+ (NSString *)base64encodeData:(NSData *)data {
    static const char cb64[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const unsigned char *dataptr = [data bytes];
    const NSUInteger input_length = [data length];
    NSMutableString *response = [NSMutableString stringWithCapacity:input_length*2];
    
    for(NSUInteger i=0; i<input_length;) {
        const uint32_t octet_a = i < input_length ? dataptr[i++] : ((void)(i++), 0);
        const uint32_t octet_b = i < input_length ? dataptr[i++] : ((void)(i++), 0);
        const uint32_t octet_c = i < input_length ? dataptr[i++] : ((void)(i++), 0);
        
        const uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;
        [response appendFormat:@"%c", cb64[(triple >> 3 * 6) & 0x3F]];
        [response appendFormat:@"%c", cb64[(triple >> 2 * 6) & 0x3F]];
        if (i-2 < input_length)
            [response appendFormat:@"%c", cb64[(triple >> 1 * 6) & 0x3F]];
        if (i-1 < input_length)
            [response appendFormat:@"%c", cb64[(triple >> 0 * 6) & 0x3F]];
    }
    
    static const int mod_table[] = {0, 2, 1};
    for (int i = 0; i < mod_table[input_length % 3]; i++)
        [response appendString:@"="];
    
    return response;
}

- (NSString *)base64encodeString:(NSString *)string {
    return [[self class] base64encodeData:[string dataUsingEncoding:encoding]];
}

- (void)prepare {
    if (_HTTPShouldHandleCookies && _customCookiesStorage) {
        NSArray * cookies = [_customCookiesStorage cookiesForURL:urlRequest.URL];
        NSDictionary * requestHeaderFieldsWithCookies = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        NSString * cookiesHeaderValue = [requestHeaderFieldsWithCookies valueForKey:@"Cookie"];
        if (cookiesHeaderValue) {
            [urlRequest setValue:cookiesHeaderValue forHTTPHeaderField:@"Cookie"];
        }
    }

    [formPost setupPostFormRequest:urlRequest encoding:encoding];

    // generate input stream using Creation Block 
    if (urlRequest.HTTPBodyStream == nil && HTTPBodyStreamCreationBlock) {
        NSInputStream *inputStream = HTTPBodyStreamCreationBlock();
        [self setHTTPBodyStream:inputStream contentType:nil];
    }
    
}

- (NSInputStream *)regenerateBodyStream {
    if (formPost) {
        NSInputStream *newStream = [formPost setupPostFormRequest:nil encoding:encoding];
        if (newStream == nil) {
            NSLog(@"RDHTTP: we have tried to re-generate form post input stream, but failed");
        }
        return newStream;
    }
    
    if (postBodyFilePath) {
        return [NSInputStream inputStreamWithFileAtPath:self.postBodyFilePath];
    }
    
    if (HTTPBodyStreamCreationBlock) {
        NSInputStream *inputStream = HTTPBodyStreamCreationBlock();
        if (inputStream) 
            return inputStream;
    }
    
    NSLog(@"RDHTTP: regenerateBodyStream was called, but we returned nil");
    NSLog(@"Examine how post body stream was set. Check HTTPBodyInputStreamCreationBlock");
    return nil;
}

@end



#pragma mark - RDHTTPFormPost

@interface RDHTTPMultipartPostStream()

- (id)initWithPostFields:(NSDictionary *)postFields
     multipartPostFields:(NSDictionary *)multipartPostFields
                encoding:(NSStringEncoding)encoding;

@end


@interface RDHTTPFormPost() {
    // user storage
    NSMutableDictionary *postFields;
    NSMutableDictionary *multipartPostFiles;
}

- (NSData *)formURLEncodedBodyWithEncoding:(NSStringEncoding)encoding;
@end

@implementation RDHTTPFormPost

- (void)dealloc
{
    [postFields release];
    [multipartPostFiles release];    
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
    RDHTTPFormPost *copy = [RDHTTPFormPost new];
    copy->postFields = [postFields copyWithZone:zone];
    copy->multipartPostFiles = [multipartPostFiles copyWithZone:zone];    
    return copy;
}

- (void)setPostValue:(NSString *)value forKey:(NSString *)key {
    if (key == nil) {
        NSLog(@"RDHTTP: null key in %s", __PRETTY_FUNCTION__);
        return;
    }
    
    if (postFields == nil)
        postFields = [NSMutableDictionary new];
    
    if (key == nil) {
        NSLog(@"RDHTTP: null key in RDHTTPFormPost setPostValue:forKey:");
        return;
    }
    
    if (value == nil) {
        NSLog(@"RDHTTP: null value for key %@ in %s", key, __PRETTY_FUNCTION__);
        value = @"(null)";
    }

    [postFields setObject:value forKey:key];
}

- (void)setFile:(NSURL *)fileURL forKey:(NSString *)key {
    [self setFile:fileURL fileName:[fileURL lastPathComponent] forKey:key];
}

- (void)setFile:(NSURL *)fileURL fileName:(NSString*)fileName forKey:(NSString *)key {
    if (key == nil) {
        NSLog(@"RDHTTP: null key in %s", __PRETTY_FUNCTION__);
        return;
    }
    
    if ([fileURL isFileURL] == NO) { // also this is nil check
        NSLog(@"RDHTTP: setFile accepts only file URLs");
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]] == NO) {
        NSLog(@"RDHTTP: not-existing file %@ in RDHTTPFormPost setFile", fileURL);
        return;
    }

    if (nil == fileName) {
        fileName = [fileURL lastPathComponent];
    }
    
    if (multipartPostFiles == nil) 
        multipartPostFiles = [NSMutableDictionary new];
    
    [multipartPostFiles setObject:@{@"fileURL" : fileURL, @"fileName" : fileName} forKey:key];
}

- (void)setData:(NSData *)data
    withFileName:(NSString *)fileName
    andContentType:(NSString *)contentType
    forKey:(NSString *)key {

    NSDictionary *fields = @{
        @"fileURL" : data,
        @"fileName" : fileName,
        @"contentType" : contentType
    };

    if (nil == multipartPostFiles) {
        multipartPostFiles = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
    }

    [multipartPostFiles setObject:fields forKey:key];
}

- (NSInputStream*)multipartPostStreamWithEncoding:(NSStringEncoding)encoding {
    RDHTTPMultipartPostStream* postStream = nil;
    
    if (multipartPostFiles) {
        postStream = [[RDHTTPMultipartPostStream alloc] initWithPostFields:postFields
                                                       multipartPostFields:multipartPostFiles
                                                                  encoding:encoding];
    }
    return [postStream autorelease];
}

#pragma mark - internal

- (NSData *)dataByAddingPercentEscapesToString:(NSString *)string usingEncoding:(CFStringEncoding)encoding {
    CFStringRef retval;
    
    retval = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                     (CFStringRef)string,
                                                     NULL,
                                                     CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
                                                     encoding);
    if (retval == nil) {
        return [NSData data];
    }
    
    CFDataRef data = CFStringCreateExternalRepresentation(kCFAllocatorDefault, retval, encoding, '?');
    CFRelease(retval);
    
    return [(NSData *)data autorelease];
}

- (NSInputStream *)setupPostFormRequest:(NSMutableURLRequest *)request encoding:(NSStringEncoding)encoding {
    NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding));

    if (multipartPostFiles) {
        // multipart/form-data, stream
        
        RDHTTPMultipartPostStream *postStream;
        
        postStream = [[RDHTTPMultipartPostStream alloc] initWithPostFields:postFields
                                                       multipartPostFields:multipartPostFiles
                                                                  encoding:encoding];
        
        [request        addValue:[NSString stringWithFormat:@"%lu", (unsigned long)postStream.multipartBodyLength]
              forHTTPHeaderField:@"Content-Length"];
        
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", charset, postStream.contentBoundary];
        [request addValue:contentType forHTTPHeaderField:@"Content-Type"];

        [request setHTTPBodyStream:postStream];
        
        return [postStream autorelease];
    }
    else {
        // x-www-form-urlencoded body, in memory 
        if (postFields == nil)
            return nil;

        NSString *contentType = [NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset];
        [request addValue:contentType forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[self formURLEncodedBodyWithEncoding:NSUTF8StringEncoding]];
    }
    
    return nil;
}

- (NSInputStream *)HTTPBodyStreamWithEncoding:(NSStringEncoding)encoding contentType:(NSString**)contentType contentLength:(NSUInteger*)contentLength {
    NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(encoding));

    if (multipartPostFiles) {
        // multipart/form-data, stream

        RDHTTPMultipartPostStream *postStream = [[RDHTTPMultipartPostStream alloc] initWithPostFields:postFields
                                                                                  multipartPostFields:multipartPostFiles
                                                                                             encoding:encoding];

        if (contentLength) {
            *contentLength = postStream.multipartBodyLength;
        }

        if (contentType) {
            *contentType = [NSString stringWithFormat:@"multipart/form-data; charset=%@; boundary=%@", charset, postStream.contentBoundary];
        }

        return [postStream autorelease];
    }
    else {
        // x-www-form-urlencoded body, in memory
        if (postFields == nil)
            return nil;

        NSData * formData = [self formURLEncodedBodyWithEncoding:NSUTF8StringEncoding];

        if (contentLength) {
            *contentLength = formData.length;
        }

        if (contentType) {
            *contentType = [NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset];
        }

        return [NSInputStream inputStreamWithData:formData];
    }

    return nil;
}


- (NSData *)formURLEncodedBodyWithEncoding:(NSStringEncoding)encoding {
    
    NSMutableData *data = [NSMutableData data];
    
    BOOL first = YES;
    CFStringEncoding enc = CFStringConvertNSStringEncodingToEncoding(encoding);
    
    for (NSString *key in postFields) {
        if (first == NO)
            [data appendBytes:"&" length:1];
        
        [data appendData:[self dataByAddingPercentEscapesToString:key usingEncoding:enc]];
        [data appendBytes:"=" length:1];
        [data appendData:[self dataByAddingPercentEscapesToString:[postFields objectForKey:key]
                                                    usingEncoding:enc]];
        first = NO;
    }
    
    return data;
}

#pragma mark - utilities 

+ (NSString *)guessContentTypeForURL:(NSURL *)fileURL defaultEncoding:(NSStringEncoding)encoding {
    // no charset ; charset=... is currently added, encoding is unused

    // Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[fileURL pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return [(NSString *)MIMEType autorelease];
}


+ (NSString*)stringByAddingPercentEscapesToString:(NSString *)string
{
    CFStringRef retval;
    
    retval = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                     (CFStringRef)string,
                                                     NULL,
                                                     CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
                                                     CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    
    return [(NSString *)retval autorelease];
}

@end


@implementation RDHTTPMultipartPostStream {
    NSString            *contentBoundary;
    NSUInteger          multipartBodyLength;
    NSMutableArray      *multipartDataArray;
    
    NSUInteger          currentBufferIndex;
    NSUInteger          currentBufferPosition;
    NSData              *currentFileData;
    NSURL               *currentFileDataURL;
    
    NSStreamStatus      streamStatus;
}

@synthesize multipartBodyLength;
@synthesize contentBoundary;

- (id)initWithPostFields:(NSDictionary *)postFields
     multipartPostFields:(NSDictionary *)multipartPostFiles
                encoding:(NSStringEncoding)encoding 
{
    self = [super init];
    if (self) {
        streamStatus = NSStreamStatusNotOpen;
        multipartDataArray = [NSMutableArray new];
        
        CFUUIDRef theUUID = CFUUIDCreate(NULL);
        contentBoundary = (NSString *)CFUUIDCreateString(NULL, theUUID);
        CFRelease(theUUID);
        
        NSMutableData *simpleFieldsData = [NSMutableData dataWithCapacity:1024];
        
        NSString *boundaryBegin = [NSString stringWithFormat:@"--%@\r\n", contentBoundary];
        [simpleFieldsData appendData:[boundaryBegin dataUsingEncoding:encoding]];
        
        NSData *boundaryMiddle = [[NSString stringWithFormat:@"\r\n--%@\r\n", contentBoundary] dataUsingEncoding:encoding];
        
        BOOL first = YES;
        for (NSString *key in postFields) {
            if (first == NO) {
                [simpleFieldsData appendData:boundaryMiddle];
            }
            
            NSString *formData;
            formData = [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@", key, [postFields objectForKey:key]];
            [simpleFieldsData appendData:[formData dataUsingEncoding:encoding]];
            
            first = NO;
        }
        
        [multipartDataArray addObject:simpleFieldsData];
        
        for(NSString *key in multipartPostFiles) {
            NSURL *fileURL = [[multipartPostFiles objectForKey:key] objectForKey:@"fileURL"];
            NSString *fileName = [[multipartPostFiles objectForKey:key] objectForKey:@"fileName"];
            NSString *contentType = [[multipartPostFiles objectForKey:key] objectForKey:@"contentType"];

            // Some kind of dirty hack is used here.
            // Down the flow fileURL is accepted as NSURL or NSData object
            // so, here it needs some protection for FileManager's and guessContentTypeForURL: methods

            if ([fileURL isKindOfClass:[NSURL class]] &&
                (NO == [[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]])) {

                NSLog(@"RDHTTP: no file %@ exists", fileURL);
                continue;
            }
            
            if (first == NO) {
                [multipartDataArray addObject:boundaryMiddle];
            }
            
            NSMutableString *fileHeaders = [NSMutableString stringWithCapacity:256];
            if (nil == contentType) {
                if ([fileURL isKindOfClass:[NSURL class]]) {
                    contentType = [RDHTTPFormPost guessContentTypeForURL:fileURL defaultEncoding:encoding];
                }
                else {
                    contentType = @"application/octet-stream";
                }
            }

            [fileHeaders appendFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, fileName];
            [fileHeaders appendFormat:@"Content-Type: %@\r\n\r\n", contentType];
            
            [multipartDataArray addObject:[fileHeaders dataUsingEncoding:encoding]];
            [multipartDataArray addObject:fileURL];
            first = NO;
        }
        
        
        NSString *boundaryEnd = [NSString stringWithFormat:@"\r\n--%@--\r\n", contentBoundary];
        [multipartDataArray addObject:[boundaryEnd dataUsingEncoding:encoding]];
        
        
        // calculate length
        multipartBodyLength = 0;
        for (NSObject *part in multipartDataArray) {
            if ([part isKindOfClass:[NSData class]]) {
                multipartBodyLength += [(NSData *)part length];
                //NSLog(@"\n%@", [[[NSString alloc] initWithData:(NSData *)part encoding:NSUTF8StringEncoding] autorelease]);
            }
            else if ([part isKindOfClass:[NSURL class]]) {
                //NSLog(@"\n%@", part);
                
                NSError *error = nil;
                NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:[(NSURL *)part path]
                                                                                      error:&error];
                
                unsigned long long fileSize = [dict fileSize];
                multipartBodyLength += (NSUInteger)fileSize;
            }
        }
        
    }
    return self;
}

- (void)dealloc {
    [multipartDataArray release];
    [contentBoundary release];
    [currentFileDataURL release];
    [currentFileData release];

    [super dealloc];
}

#pragma mark - input stream methods 

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    //NSLog(@"%s = %d", __func__, len);
    
    if ([self hasBytesAvailable] == NO)
        return 0;
    
    streamStatus = NSStreamStatusReading;
    
    NSObject *currentPart = [multipartDataArray objectAtIndex:currentBufferIndex];
    
    NSData *data = nil;
    if ([currentPart isKindOfClass:[NSData class]]) {
        data = (NSData *)currentPart;
    }
    else if ([currentPart isKindOfClass:[NSURL class]]) {
        NSURL *url = (NSURL *)currentPart;
        
        if ([url isEqual:currentFileDataURL] == NO) {
            [currentFileDataURL release];
            [currentFileData release];
            
            currentFileData = [[NSData alloc] initWithContentsOfURL:url
                                                            options:NSDataReadingMappedIfSafe
                                                              error:nil];
            currentFileDataURL = [url copy];
        }
        
        data = currentFileData;
    }
    
    if (len >= [data length] - currentBufferPosition) {
        len = [data length] - currentBufferPosition;
        
        [data getBytes:buffer range:NSMakeRange(currentBufferPosition, len)];
        currentBufferIndex++;
        currentBufferPosition = 0;
    }
    else {
        [data getBytes:buffer range:NSMakeRange(currentBufferPosition, len)];
        currentBufferPosition += len;
    }
    
    streamStatus = NSStreamStatusOpen;
    return len;
}

- (BOOL)hasBytesAvailable {
    return currentBufferIndex < [multipartDataArray count];
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
    return NO;
}

- (void)open {
    streamStatus = NSStreamStatusOpen;
}

- (void)close {
    [multipartDataArray release];
    multipartDataArray = nil;
    streamStatus = NSStreamStatusClosed;
}

- (NSStreamStatus)streamStatus {
    if (multipartDataArray && [self hasBytesAvailable] == NO)
        return NSStreamStatusAtEnd;
    
    return streamStatus;
}

- (NSError *)streamError {
    return nil;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    // Nothing to do here, because this stream does not implement a run loop to produce its data.
    // Should we bother to implement this method? Contact andrian@readdle.com if you know positive answer
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    // Nothing to do here, because this stream does not implement a run loop to produce its data.
    // Should we bother to implement this method? Contact andrian@readdle.com if you know positive answer
}

- (void) _scheduleInCFRunLoop: (CFRunLoopRef) inRunLoop forMode: (CFStringRef) inMode {
    // Nothing to do here, because this stream does not implement a run loop to produce its data.
    // Should we bother to implement this method? Contact andrian@readdle.com if you know positive answer
}

- (void) _unscheduleFromCFRunLoop:(CFRunLoopRef)inRunLoop forMode:(CFStringRef)inMode {
    // Nothing to do here, because this stream does not implement a run loop to produce its data.
    // Should we bother to implement this method? Contact andrian@readdle.com if you know positive answer
}

- (BOOL) _setCFClientFlags: (CFOptionFlags)inFlags
                  callback: (CFReadStreamClientCallBack) inCallback
                   context: (CFStreamClientContext *) inContext
{
    // Nothing to do here, because this stream does not implement a run loop to produce its data.
    // Should we bother to implement this method? Contact andrian@readdle.com if you know positive answer
    return NO;
}

@end


#pragma mark - RDHTTP Form Get

@implementation RDHTTPFormGet {
    NSURL *_URL;
    NSMutableString *_params;
    
}

- (id)initWithURL:(NSURL *)URL {
    if ((self = [super init]) != nil) {
        if (URL == nil) {
            [self release];
            return nil;
        }
            
        _URL = [URL retain];
        if ([URL query]) {
            _params = [[NSMutableString alloc] initWithString:URL.query];
        }
        else {
            _params = [[NSMutableString alloc] initWithCapacity:64];
        }
    }
    return self;
}

- (void)dealloc
{
    [_URL release];
    [_params release];
    [super dealloc];
}


+ (id)formGetWithURL:(NSURL *)URL {
    return [[[[self class] alloc] initWithURL:URL] autorelease];
}

+ (id)formGetWithURLString:(NSString *)URLString {
    NSURL *URL = [NSURL URLWithString:URLString];
    return [[[[self class] alloc] initWithURL:URL] autorelease];
}

- (void)addGetValue:(NSString *)value forKey:(NSString *)key {
    if (key == nil) {
        NSLog(@"RDHTTP: null key in %s", __PRETTY_FUNCTION__);
        return;
    }
    
    
    if ([_params length] > 0)
        [_params appendString:@"&"];
    
    
    if (value == nil) {
        NSLog(@"RDHTTP: null value for key %@ in %s", key, __PRETTY_FUNCTION__);
        value = @"(null)";
    }
    
    [_params appendFormat:@"%@=%@",
     [RDHTTPFormPost stringByAddingPercentEscapesToString:key],
     [RDHTTPFormPost stringByAddingPercentEscapesToString:value]];
}

- (NSURL *)encodedURL {
    NSMutableString *URLString = [NSMutableString stringWithCapacity:256];
    
    if ([_params length] == 0)
        return _URL;
    
    [URLString appendFormat:@"%@://", [_URL scheme]];
    
    if ([_URL user]) {
        [URLString appendString:[_URL user]];
        
        if ([_URL password])
            [URLString appendFormat:@":%@", [_URL password]];
        
        [URLString appendString:@"@"];
    }
    
    
    [URLString appendString:[_URL host]];
    
    if ([_URL port])
        [URLString appendFormat:@":%d", [[_URL port] intValue]];
    
    [URLString appendString:[_URL path]];
    
    if ([_URL parameterString])
        [URLString appendFormat:@";%@", [_URL parameterString]];
    
    
    [URLString appendFormat:@"?%@", _params];
    
    if ([_URL fragment])
        [URLString appendFormat:@"#%@", [_URL fragment]];
    
    return [NSURL URLWithString:URLString];
}

@end








#pragma mark - Challenge Decision Helper Objects

@interface RDHTTPChallangeDecision() {
@protected
    NSURLAuthenticationChallenge *challenge;
    NSString *host;
}
- (id)initWithChallenge:(NSURLAuthenticationChallenge *)aChallenge host:(NSString *)aHost;
@end

@implementation RDHTTPChallangeDecision
@synthesize host;
- (id)initWithChallenge:(NSURLAuthenticationChallenge *)aChallenge host:(NSString *)aHost {
    self = [super init];
    if (self) {
        challenge = [aChallenge retain];
        host = [aHost retain];
    }
    return self;
}

- (void)cancel {
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)dealloc {
    [host release];
    [challenge release];
    [super dealloc];
}
@end


@implementation RDHTTPAuthorizer
@dynamic host;

- (void)continueWithUsername:(NSString *)username password:(NSString *)password {

    // pastey:
    // We used NSURLCredentialPersistenceNone. Unfortunatelly it was broken in iOS 8
    // Other people complain too https://devforums.apple.com/message/1037049#1037049
    // Sync with any Microsoft IIS with NTLM (for example, out iis.rdl.as or https://j.readdle.com/browse/ESP-51) does not work.
    // Use of NSURLCredentialPersistenceForSession seems to fix this problem
    //
    // NSURLCredentialPersistenceNone was fixed in 8.1
    //

    NSURLCredentialPersistence persistence = NSURLCredentialPersistenceForSession;
    if (RDHTTPUseCredentialPersistenceNone) {
        persistence = NSURLCredentialPersistenceNone;
    }

    NSURLCredential *credential = [NSURLCredential credentialWithUser:username
                                                             password:password
                                                          persistence:persistence];

    [[challenge sender] useCredential:credential
           forAuthenticationChallenge:challenge];
     
}

- (void)cancelAuthorization {
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

@end

@implementation RDHTTPSSLServerTrust
@dynamic host;

- (void)trust {
    [[challenge sender] useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] 
           forAuthenticationChallenge:challenge];
}
- (void)dontTrust {
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

@end


#pragma mark - RDHTTPThread

static NSThread *_rdhttpThread;

/** RDHTTPThread is a basic runloop-enabled NSThread that will work for HTTP request processing.
 *
 */
@interface RDHTTPThread : NSThread {
}

/** Returns default instance of RDHTTPThread */
+ (NSThread *)defaultThread;
@end

@implementation RDHTTPThread

+ (NSThread *)defaultThread {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (_rdhttpThread == nil) {
            _rdhttpThread = [[RDHTTPThread alloc] init];
            [_rdhttpThread start];
        }            
    });
    
    return _rdhttpThread;
}

- (void)main {
    @autoreleasepool {
        self.name = @"RDHTTPConnectionThread";
        pthread_setname_np("RDHTTPConnectionThread");
        [NSTimer scheduledTimerWithTimeInterval:1000000 target:[NSNull null] selector:@selector(description) userInfo:nil repeats:YES];
        
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        BOOL hasSources = YES;
        
        while(!self.isCancelled && hasSources) {
            @autoreleasepool {
                hasSources = [loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
            }
        }
    }
}

@end





#pragma mark - RDHTTPOperation

@interface RDHTTPOperation()<NSURLConnectionDataDelegate, NSURLConnectionDelegate> {
    RDHTTPRequest       *request; // this object is mutable, we agreed to use our copy for non-mutable tasks only
    
    NSString            *tempFilePath;
    NSFileHandle        *tempFileHandle;
    
    BOOL                sendProgressUpdates;
    
    NSURLConnection     *connection;
    long long           httpExpectedContentLength;
    long long           httpSavedDataLength;
    NSHTTPURLResponse   *httpResponse;
    NSMutableData       *httpResponseData;
    
    
    BOOL                isCancelled;
    BOOL                isExecuting;
    BOOL                isFinished;
}

- (void)_start;

@end

@implementation RDHTTPOperation

+ (void)setThread:(NSThread*)thread {
    NSAssert(_rdhttpThread == nil, @"RDHTTPOperation: called setThread after thread initialization");
    _rdhttpThread = [thread retain];
}

- (id)initWithRequest:(RDHTTPRequest *)aRequest {
    self = [super init];
    if (self) {
        request = [aRequest copy];
        dispatch_queue_set_specific(request.dispatchQueue, self, RDHTTPDispatchQueueActive, NULL);
        sendProgressUpdates = YES;
    }
    return self;
}

- (void)dealloc {
    dispatch_queue_set_specific(request.dispatchQueue, self, NULL, NULL);
    [request release];
    
    [httpResponse release];
    [httpResponseData release];
    
    [tempFilePath release];
    [tempFileHandle release];
    
    [super dealloc];
}

#pragma mark - Operation methods 
@synthesize isExecuting;
@synthesize isCancelled;
@synthesize isFinished;

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    if (self.isCancelled || self.isExecuting) {
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    NSAssert(isExecuting && isFinished == NO, @"RDHTTPOperation: someone called -(void)start twice");
    
    if (request.useInternalThread) {
        if (_rdhttpThread == nil) {
            _rdhttpThread = [RDHTTPThread defaultThread];
        }
        
        [self performSelector:@selector(_start) onThread:_rdhttpThread withObject:nil waitUntilDone:NO];
    }
    else 
        [self _start];
}

- (void)_start {
    [request prepare];
    connection = [[[NSURLConnection alloc] initWithRequest:[request _nsurlrequest]
                                                  delegate:self
                                          startImmediately:NO] autorelease];

    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
}
             


- (void)_cancel {
    if (self.isCancelled) 
        return;
    
    [self retain];
    
    [connection cancel];
    connection = nil;
    [self cleanTempFile];
    
    [self willChangeValueForKey:@"isCancelled"];
    isCancelled = YES;
    [self didChangeValueForKey:@"isCancelled"];
    
    [self release];
    return;
}

- (void)cancel {
    // We have to retain self here, because operation may be released
    // on completion before dispatch_sync will execute its block.
    // dispatch_sync DOES NOT copy its block, so self will not be retained there
    // and we will crash.
    [self retain];

    // check if current queue is request.dispatchQueue 
    if (dispatch_get_specific(self) == RDHTTPDispatchQueueActive) {
        [self _cancel];
    }
    else {
        dispatch_sync(request.dispatchQueue, ^{
            [self _cancel];
        });
    }
    [self release];
}

- (void)prepareTempFile {
    
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    NSString *tempUUID = (NSString *)CFUUIDCreateString(NULL, theUUID);
    NSString *tempName = [NSString stringWithFormat:@"RDHTTP-%@", tempUUID];
    
    [tempUUID release];
    CFRelease(theUUID);

    tempFilePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:tempName] retain];
    [[NSFileManager defaultManager] createFileAtPath:tempFilePath contents:[NSData data] attributes:nil];
    tempFileHandle = [[NSFileHandle fileHandleForWritingAtPath:tempFilePath] retain];
}

- (void)cleanTempFile
{
    if (tempFilePath)
        [[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
}

#pragma mark - NSURLConnection delegate / dataSource

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {
    connection = nil;
    [tempFileHandle closeFile];
    
    rdhttp_block_t completionBlock = request.completionBlock;
    
    if (completionBlock && [self isCancelled] == NO) {    
        RDHTTPResponse *response = [[[RDHTTPResponse alloc] initWithResponse:nil
                                                                     request:request
                                                                       error:error
                                                                tempFilePath:tempFilePath
                                                                        data:nil] autorelease];
        
        dispatch_async(request.dispatchQueue, ^{
            if (self.isCancelled)
                return;
            
            completionBlock(response);
            [self cleanTempFile];
        });
    }
    else {
            [self cleanTempFile];
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    isExecuting = NO;
    isFinished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse {
    NSAssert([aResponse isKindOfClass:[NSHTTPURLResponse class]], @"NSURLConnection did not return NSHTTPURLResponse");

    [httpResponse release];
    httpResponse = [(NSHTTPURLResponse *)aResponse retain];
    long long expectedContentLength = [aResponse expectedContentLength];
    httpExpectedContentLength = expectedContentLength;
    
    if (request.shouldSaveResponseToFile) {
        [self prepareTempFile];    
    }
    else if (nil == request.responseDataHandler) {
        NSUInteger dataCapacity = 8192;
        if (expectedContentLength != NSURLResponseUnknownLength)
            dataCapacity = (NSUInteger)expectedContentLength;
        
        [httpResponseData release];
        httpResponseData = [[NSMutableData alloc] initWithCapacity:dataCapacity];
    }

    if (request.HTTPShouldHandleCookies) {
        RDHTTPCookiesStorage * customCookiesStorage = [request customCookiesStorage];
        if (customCookiesStorage) {
            NSArray * receivedCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:((NSHTTPURLResponse *)aResponse).allHeaderFields forURL:request.URL];
            if (receivedCookies.count > 0) {
                for (NSHTTPCookie * cookie in receivedCookies) {
                    [customCookiesStorage setCookie:cookie forURL:request.URL];
                }
                [customCookiesStorage save];
            }
        }
    }

    if (request.headersHandler && [self isCancelled] == NO) {
        RDHTTPResponse *response = [[[RDHTTPResponse alloc] initWithResponse:((NSHTTPURLResponse *)aResponse)
                                                                     request:request
                                                                       error:nil
                                                                tempFilePath:nil // too early to pass tempFilePath, it is empty
                                                                        data:nil] autorelease];
        
        dispatch_async(request.dispatchQueue, ^{
            if (self.isCancelled)
                return;
            request.headersHandler(response, self);
        });
    }
    
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (httpResponseData) {
        [httpResponseData appendData:data];
    }
    else if (tempFileHandle) {
        [tempFileHandle writeData:data];
    }
    else if (request.responseDataHandler) {
        request.responseDataHandler(data);
    }
    
    httpSavedDataLength += [data length];
    
    if (request.downloadProgressHandler && sendProgressUpdates) {
        rdhttp_progress_block_t progressBlock = request.downloadProgressHandler;
        
        if (httpExpectedContentLength > 0) {
            float progress = (float)httpSavedDataLength  / (float)httpExpectedContentLength;
            
            dispatch_async(request.dispatchQueue, ^{
                if (self.isCancelled) {
                    return;
                }
                progressBlock(progress);
            });
        }
        else {
            dispatch_async(request.dispatchQueue, ^{
                if (self.isCancelled) {
                    return;
                }
                progressBlock(-1.0f);
            });
            sendProgressUpdates = NO;
        }
    }
}

- (void)        connection:(NSURLConnection *)connection 
           didSendBodyData:(NSInteger)bytesWritten 
         totalBytesWritten:(NSInteger)totalBytesWritten 
 totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite 
{
    if (request.uploadProgressHandler) {
        rdhttp_progress_block_t progressBlock = request.uploadProgressHandler;
        
        if (totalBytesExpectedToWrite > 0) {
            float progress = (float)totalBytesWritten  / (float)totalBytesExpectedToWrite;
            
            dispatch_async(request.dispatchQueue, ^{
                if (self.isCancelled) {
                    return;
                }
                progressBlock(progress);
            });
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection {
    connection = nil;
    [tempFileHandle closeFile];
    rdhttp_block_t completionBlock = request.completionBlock;
    
    if (completionBlock == nil || [self isCancelled]) {
        [self cleanTempFile];
        return;
    }
    
    RDHTTPResponse *response = [[RDHTTPResponse alloc] initWithResponse:httpResponse
                                                                request:request
                                                                  error:nil
                                                           tempFilePath:tempFilePath
                                                                   data:httpResponseData];
    [response autorelease];
    
    [httpResponseData release]; // response retains this
    httpResponseData = nil;

    
    dispatch_async(request.dispatchQueue, ^{
        if (NO == self.isCancelled) {
            completionBlock(response);
        }

        [self cleanTempFile];
    });
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    isExecuting = NO;
    isFinished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)newURLRequest
            redirectResponse:(NSURLResponse *)redirectResponse 
{
    if (redirectResponse == nil) // transforming to canonical form
        return newURLRequest;
    
    if (request.shouldRedirect) {
        if (request.shouldUseRFC2616RedirectBehaviour) {
            NSMutableURLRequest *new2616request = [[[request _nsurlrequest] mutableCopy] autorelease];
            [new2616request setURL:newURLRequest.URL];

            if (request.shouldReplaceHTTPHeaderFieldsOnRFC2616RedirectBehaviour) {
                // vs.savchenko@readdle.com: 'setAllHTTPHeaderFields:' is doing UNION from old and new sets of values
                for (NSString *headerKey in [[new2616request allHTTPHeaderFields] allKeys]) {
                    [new2616request setValue:nil forHTTPHeaderField:headerKey];
                }
                for (NSString *headerKey in [[newURLRequest allHTTPHeaderFields] allKeys]) {
                    [new2616request setValue:([newURLRequest allHTTPHeaderFields])[headerKey] forHTTPHeaderField:headerKey];
                }
            }
            return new2616request;
        }
        
        return newURLRequest;
    }
    
    return nil;
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection {
	return YES;
}

- (NSInputStream *) connection:(NSURLConnection *)aConnection needNewBodyStream:(NSURLRequest *)resentRequest {
    NSInputStream* inputStream = [request regenerateBodyStream];
    
    if (inputStream == nil) {
        NSError* error = [NSError errorWithDomain:RDHTTPResponseCodeErrorDomain
                                             code:RDHTTP_REGENERATE_BODY_STREAM_ERROR
                                         userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Unable to regenerate body stream.", @"")
                                                                              forKey:NSLocalizedDescriptionKey]];
        
        [self connection:aConnection didFailWithError:error];
    }
    return inputStream;
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSString *host = [[request _nsurlrequest].URL host];

    if ([challenge.protectionSpace.authenticationMethod isEqualToString:@"NSURLAuthenticationMethodServerTrust"]) {
        SecTrustResultType resultType;
        OSStatus checkResult = SecTrustEvaluate(challenge.protectionSpace.serverTrust, &resultType);

        if (errSecSuccess == checkResult) {
            if ((kSecTrustResultUnspecified == resultType) ||
                (kSecTrustResultProceed == resultType)) {

                NSURLCredential *credential =
                    [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];

                [[challenge sender] useCredential:credential
                    forAuthenticationChallenge:challenge];

                return;
            }
        }


        // Identity check is failed, let client to decide trust

        // certificate trust
        RDHTTPSSLServerTrust *serverTrust = [[RDHTTPSSLServerTrust alloc] initWithChallenge:challenge host:host];
        
        rdhttp_trustssl_block_t trust = [request SSLCertificateTrustHandler];
        if (trust == nil) {
            [serverTrust dontTrust];
            [serverTrust release];
            return;
        }

        dispatch_async(request.dispatchQueue, ^{ 
            if (self.isCancelled)
                return;
            trust(serverTrust);
        });
        [serverTrust release];

    }
    else {
        // normal login-password auth: 
        const int kAllowedLoginFailures = 1;
        RDHTTPAuthorizer *httpAuthorizer = [[RDHTTPAuthorizer alloc] initWithChallenge:challenge host:host];
        
        rdhttp_httpauth_block_t auth = [request HTTPAuthHandler];
        
        if ((auth == nil)||([challenge previousFailureCount] >= kAllowedLoginFailures)) {
            [httpAuthorizer cancelAuthorization];
            [httpAuthorizer release];
            return;
        }
            
        dispatch_async(request.dispatchQueue, ^{
            if (self.isCancelled)
                return;
            
            auth(httpAuthorizer);
        });
        
        [httpAuthorizer release];
    }
}

@end


@implementation RDHTTPCookiesStorage
{
    NSMutableDictionary * _tailMatchDomainCookies;
    NSMutableDictionary * _exactMatchDomainCookies;
    NSString* _storageLocation;
}

- (instancetype) initWithStoarageLocation:(NSString*)storageLocation {
    self = [self init];
    if (self) {
        _storageLocation = [storageLocation copy];
        [self load];
    }
    return self;
}

- (instancetype) init {
    self = [super init];
    if (self) {
        _tailMatchDomainCookies = [NSMutableDictionary new];
        _exactMatchDomainCookies = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc
{
    [self save];

    [_tailMatchDomainCookies release];
    [_exactMatchDomainCookies release];
    [_storageLocation release];
    [super dealloc];
}

- (BOOL) load {
    NSAssert(_storageLocation, @"");
    if (nil == _storageLocation) {
        return NO;
    }

    NSArray * cookieDictionaries = [NSArray arrayWithContentsOfFile:_storageLocation];
    if (nil == cookieDictionaries) {
        return NO;
    }

    for (NSDictionary * cookieProperties in cookieDictionaries) {
        NSHTTPCookie * cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
        if ([self isExpiredCookie:cookie]) {
            continue;
        }

        NSMutableArray * cookiesForDomain = [self provideArrayOfCookiesForDomain:cookie.domain];
        [cookiesForDomain addObject:cookie];
    }

    return NO;
}

- (BOOL) save {
    if (nil == _storageLocation) {
        return NO;
    }

    @synchronized(self) {
        NSMutableArray * cookies = [[NSMutableArray new] autorelease];
        for (NSArray * cookiesForDomain in [_exactMatchDomainCookies allValues]) {
            [cookies addObjectsFromArray:cookiesForDomain];
        }
        for (NSArray * cookiesForDomain in [_tailMatchDomainCookies allValues]) {
            [cookies addObjectsFromArray:cookiesForDomain];
        }

        [cookies filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSHTTPCookie * cookie, NSDictionary *bindings) {
            return nil != cookie.expiresDate;
        }]];

        NSArray * cookieDictionaries = [cookies valueForKey:@"properties"];
        if (cookieDictionaries.count > 0) {
            BOOL res = [cookieDictionaries writeToFile:_storageLocation atomically:YES];
            NSAssert(res, @"");
            return res;
        }

        return YES;
    }
}

- (NSString*) canonicalizedDomainString:(NSString*)domainString {
    domainString = [domainString lowercaseString];
    if ([domainString hasSuffix:@"."] && domainString.length > 1) {
        domainString = [domainString substringToIndex:domainString.length-1];
    }
    return domainString;
}

- (BOOL) doesCookieDomain:(NSString*)cookieDomain matchURLDomain:(NSString*)urlDomain {
    NSAssert(cookieDomain && urlDomain, @"");
    if (nil == cookieDomain || nil == urlDomain) {
        return NO;
    }

    if ([cookieDomain hasPrefix:@"."]) {
        if ([urlDomain hasSuffix:cookieDomain]) {
            return YES;
        }

        if (cookieDomain.length > 1) {
            return [urlDomain isEqualToString:[cookieDomain substringFromIndex:1]];
        }

        return NO;
    }
    else {
        return [cookieDomain isEqualToString:urlDomain];
    }
}

- (NSUInteger) domainLevel:(NSString*)domain {
    NSArray * domainLabels = [[domain componentsSeparatedByString:@"."] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString * label, NSDictionary *bindings) {
        return label.length > 0;
    }]];
    return domainLabels.count;
}

- (BOOL) isExpiredCookie:(NSHTTPCookie*)cookie {
    return cookie.expiresDate && NSOrderedAscending == [cookie.expiresDate compare:[NSDate date]];
}

- (NSMutableArray*) provideArrayOfCookiesForDomain:(NSString*)cookieDomain {
    @synchronized(self) {
        if ([cookieDomain hasPrefix:@"."]) {
            NSMutableArray * tailMatchCookiesForDomain = [_tailMatchDomainCookies objectForKey:cookieDomain];
            if (nil == tailMatchCookiesForDomain) {
                tailMatchCookiesForDomain = [[NSMutableArray new] autorelease];
                _tailMatchDomainCookies[cookieDomain] = tailMatchCookiesForDomain;
            }
            return tailMatchCookiesForDomain;
        }
        else {
            NSMutableArray * exactMatchCookiesForDomain = [_exactMatchDomainCookies objectForKey:cookieDomain];
            if (nil == exactMatchCookiesForDomain) {
                exactMatchCookiesForDomain = [[NSMutableArray new] autorelease];
                _exactMatchDomainCookies[cookieDomain] = exactMatchCookiesForDomain;
            }
            return exactMatchCookiesForDomain;
        }
    }
}

- (void) setCookie:(NSHTTPCookie*)cookie forURL:(NSURL*)url {
    if (nil == cookie || nil == url) {
        //        log4Error();
        NSAssert(0, @"invalid argument!");
        return;
    }

    NSString * cookieDomain = [self canonicalizedDomainString:[cookie domain]];
    NSString * const urlDomain = [self canonicalizedDomainString:[url host]];

    if (nil == cookieDomain) {
        cookieDomain = urlDomain;

        if ([cookieDomain hasPrefix:@"."] && cookieDomain.length > 1) {
            // just for sure - if we take domain from URL, then the domain must be used for exact match
            cookieDomain = [cookieDomain substringFromIndex:1];
        }
    }
    else {
        if ([self domainLevel:cookieDomain] < 2) {
            // do not allow setting cookies for ".com" or ".ua." domains
            return;
        }

        if (NO == [self doesCookieDomain:cookieDomain matchURLDomain:urlDomain]) {
            // reject thirdparty cookie
            return;
        }
    }

    @synchronized(self) {
        NSMutableArray * cookiesForDomain = [self provideArrayOfCookiesForDomain:cookieDomain];

        const BOOL isExpiredCookie = [self isExpiredCookie:cookie];

        const NSUInteger indexOfCookieWithSameNameAndPath = [cookiesForDomain indexOfObjectPassingTest:^BOOL(NSHTTPCookie * existingCookie, NSUInteger idx, BOOL *stop) {
            if ([existingCookie.name isEqualToString:cookie.name] && [existingCookie.path isEqualToString:cookie.path]) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];

        if (NSNotFound != indexOfCookieWithSameNameAndPath) {
            if (isExpiredCookie) {
                [cookiesForDomain removeObjectAtIndex:indexOfCookieWithSameNameAndPath];
            }
            else {
                [cookiesForDomain replaceObjectAtIndex:indexOfCookieWithSameNameAndPath withObject:cookie];
            }
        }
        else {
            if (NO == isExpiredCookie) {
                [cookiesForDomain addObject:cookie];
            }
        }
    }
}

- (void) deleteAllCookies {
    @synchronized(self) {
        [_tailMatchDomainCookies removeAllObjects];
        [_exactMatchDomainCookies removeAllObjects];
    }
}

- (NSArray*) cookiesFromArray:(NSArray*)cookies matchingPathOfURL:(NSURL*)url {
    NSString * const urlPath = [url path];

    NSArray * cookiesMatchingPath = [cookies filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSHTTPCookie * cookie, NSDictionary *bindings) {
        if (0 == urlPath.length && [cookie.path isEqualToString:@"/"]) {
            return YES;
        }

        return [urlPath hasPrefix:cookie.path];
    }]];

    return cookiesMatchingPath;
}

- (BOOL) removeExpiredCookiesFromArray:(NSMutableArray*)cookies {
    NSMutableArray * cookiesToRemove = [[NSMutableArray new] autorelease];

    for (NSHTTPCookie * cookie in cookies) {
        if ([self isExpiredCookie:cookie]) {
            [cookiesToRemove addObject:cookie];
        }
    }

    if (cookiesToRemove.count > 0) {
        [cookies removeObjectsInArray:cookiesToRemove];
        return YES;
    }

    return NO;
}

- (NSArray*) cookiesFromArray:(NSArray*)cookies matchingSecureAttributeForURL:(NSURL*)url {
    if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
        return cookies;
    }
    else {
        NSArray * cookiesExcludingSecure = [cookies filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSHTTPCookie * cookie, NSDictionary *bindings) {
            return NO == cookie.isSecure;
        }]];
        return cookiesExcludingSecure;
    }
}

- (NSArray*) cookiesForURL:(NSURL*)url {
    NSMutableArray * cookiesMatchingDomain = [[NSMutableArray new] autorelease];

    NSString * const urlDomain = [self canonicalizedDomainString:[url host]];

    @synchronized(self) {
        NSMutableArray * const cookiesExactlyMatchingDomain = [_exactMatchDomainCookies objectForKey:urlDomain];
        if (cookiesExactlyMatchingDomain.count > 0) {
            [self removeExpiredCookiesFromArray:cookiesExactlyMatchingDomain];
            [cookiesMatchingDomain addObjectsFromArray:cookiesExactlyMatchingDomain];
        }

        for (NSString * tailMatchDomain in _tailMatchDomainCookies.allKeys) {
            if ([self doesCookieDomain:tailMatchDomain matchURLDomain:urlDomain]) {
                NSMutableArray * cookiesForTail = [_tailMatchDomainCookies objectForKey:tailMatchDomain];
                if (cookiesForTail.count > 0) {
                    [self removeExpiredCookiesFromArray:cookiesForTail];
                    [cookiesMatchingDomain addObjectsFromArray:cookiesForTail];
                }
            }
        }

        NSArray * cookiesMatchingPath = [self cookiesFromArray:cookiesMatchingDomain matchingPathOfURL:url];
        NSArray * cookiesMatchingSecureAttribute = [self cookiesFromArray:cookiesMatchingPath matchingSecureAttributeForURL:url];

        return [cookiesMatchingSecureAttribute sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(NSHTTPCookie * cookie1, NSHTTPCookie * cookie2) {
            if (cookie1.path.length > cookie2.path.length) {
                return NSOrderedAscending;
            }
            else if (cookie1.path.length < cookie2.path.length) {
                return NSOrderedDescending;
            }
            
            return NSOrderedSame;
        }];
    }
}

@end

