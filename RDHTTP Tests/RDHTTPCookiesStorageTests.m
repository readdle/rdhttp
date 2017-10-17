//
//  RDHTTPCookiesStorageTests.m
//  RDHTTPCookiesStorageTests
//
//  Created by pastey on 10/1/13.
//  Copyright (c) 2013 Readdle. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RDHTTP.h"

//@protocol RSCookiesStorage <NSObject>
//
//- (void) setCookie:(NSHTTPCookie*)cookie forURL:(NSURL*)url;
//
//- (void) deleteAllCookies;
//
//- (NSArray*) cookiesForURL:(NSURL*)url;
//
//@end
//
//@interface NSCookiesStorageWrap : NSObject <RSCookiesStorage>
//@end
//
//@implementation NSCookiesStorageWrap
//
//- (instancetype) init {
//    self = [super init];
//    return self;
//}
//
//- (void) deleteAllSessionOnlyCookies {
//    NSArray * cookies = [[[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies] copy] autorelease];
//    for (NSHTTPCookie * cookie in cookies) {
//        if (cookie.isSessionOnly) {
//            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
//        }
//    }
//}
//
//- (void)dealloc
//{
//    [self deleteAllSessionOnlyCookies];
//    [super dealloc];
//}
//
//- (void) setCookie:(NSHTTPCookie*)cookie forURL:(NSURL*)url {
//    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:@[ cookie ] forURL:url mainDocumentURL:url];
//}
//
//- (void) deleteCookie:(NSHTTPCookie*)cookie {
//    [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
//}
//
//- (void) deleteAllCookies {
//    NSArray * cookies = [[[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies] copy] autorelease];
//    for (NSHTTPCookie * cookie in cookies) {
//        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
//    }
//}
//
//- (NSArray*) cookiesForURL:(NSURL*)url {
//    return [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:url];
//}
//
//@end

@interface RDHTTPCookiesStorageTests : XCTestCase

@end

@implementation RDHTTPCookiesStorageTests
{
//    NSObject<RSCookiesStorage> * _cookiesStorage;
    RDHTTPCookiesStorage * _cookiesStorage;
}

- (RDHTTPCookiesStorage *) newCookiesStorage {
    return [[RDHTTPCookiesStorage alloc] initWithStoarageLocation:[NSTemporaryDirectory() stringByAppendingPathComponent:@"cookies.jar"]];
}

//- (NSObject<RSCookiesStorage> *) newCookiesStorage {
//    return [NSCookiesStorageWrap new];
//}

- (void)setUp
{
    [super setUp];

    _cookiesStorage = [self newCookiesStorage];
    [_cookiesStorage deleteAllCookies];
}

- (void)tearDown
{
    [_cookiesStorage deleteAllCookies];
    [_cookiesStorage release];

    [super tearDown];
}

- (NSURL*) testURL {
    return [NSURL URLWithString:@"http://example.com"];
}

- (NSString*) testDomain {
    return [[self testURL] host];
}

- (NSHTTPCookie*) cookieWithHTTPHeaderValue:(NSString*)headerValue forURL:(NSURL*)url {
    NSDictionary *dic = [NSDictionary dictionaryWithObject:headerValue forKey:@"Set-Cookie"];
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:dic forURL:url];
    return [cookies firstObject];
}

- (NSHTTPCookie*) cookieWithName:(NSString*)name value:(NSString*)value {
    return [self cookieWithName:name value:value domain:nil expirationDate:nil];
}

- (NSHTTPCookie*) cookieWithName:(NSString*)name value:(NSString*)value expirationDate:(NSDate*)expirationDate {
    return [self cookieWithName:name value:value domain:nil expirationDate:expirationDate];
}

- (NSHTTPCookie*) cookieWithName:(NSString*)name value:(NSString*)value domain:(NSString*)domain expirationDate:(NSDate*)expirationDate {
    NSMutableDictionary * cookieProperties = [[NSMutableDictionary new] autorelease];
    if (nil == domain) {
        domain = [self testDomain];
    }
    cookieProperties[NSHTTPCookieDomain] = domain;
    cookieProperties[NSHTTPCookiePath] = @"/";
    cookieProperties[NSHTTPCookieName] = name;
    cookieProperties[NSHTTPCookieValue] = value;
    if (expirationDate) {
        cookieProperties[NSHTTPCookieExpires] = expirationDate;
    }
//    cookieProperties[NSHTTPCookieDiscard] = @"FALSE";

    NSHTTPCookie * cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    return cookie;
}

- (void)testSingleAddCookie
{
    NSHTTPCookie * cookie = [self cookieWithName:@"name" value:@"value"];
    [_cookiesStorage setCookie:cookie forURL:[self testURL]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");
    XCTAssertEqualObjects(cookie, [_cookiesStorage cookiesForURL:[self testURL]].firstObject, @"cookie must be equal!");
}

- (void)testTwoAddCookie
{
    NSHTTPCookie * cookie1 = [self cookieWithName:@"name1" value:@"value1"];
    [_cookiesStorage setCookie:cookie1 forURL:[self testURL]];
    NSHTTPCookie * cookie2 = [self cookieWithName:@"name2" value:@"value2"];
    [_cookiesStorage setCookie:cookie2 forURL:[self testURL]];

    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");
    XCTAssertEqualObjects(cookie1, [_cookiesStorage cookiesForURL:[self testURL]][0], @"cookie must be equal!");
    XCTAssertEqualObjects(cookie2, [_cookiesStorage cookiesForURL:[self testURL]][1], @"cookie must be equal!");
}

- (void) testSettingCookies {
    NSHTTPCookie * yandexCookie = [self cookieWithName:@"name" value:@"value" domain:@".yandex.ru" expirationDate:nil];
    [_cookiesStorage setCookie:yandexCookie forURL:[NSURL URLWithString:@"http://market.yandex.ru/search"]];
    NSHTTPCookie * vkontakteCookie = [self cookieWithName:@"name" value:@"value" domain:@".vk.com" expirationDate:nil];
    [_cookiesStorage setCookie:vkontakteCookie forURL:[NSURL URLWithString:@"http://vk.com/id23423400"]];

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://who.yandex.ru"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://vk.com/ads/ad12333.png"]].count);
}

- (void) testSettingThirdpartyCookiesForOurURL {
    NSHTTPCookie * yandexCookie = [self cookieWithName:@"name" value:@"value" domain:@".yandex.ru" expirationDate:nil];
    [_cookiesStorage setCookie:yandexCookie forURL:[self testURL]];

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://who.yandex.ru"]].count);

    NSHTTPCookie * testDomainCookie = [self cookieWithName:@"goodCookie" value:@"value"];
    NSHTTPCookie * vkontakteCookie = [self cookieWithName:@"name" value:@"value" domain:@".vk.com" expirationDate:nil];
    [_cookiesStorage setCookie:testDomainCookie forURL:[self testURL]];
    [_cookiesStorage setCookie:vkontakteCookie forURL:[self testURL]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://vk.com/id10298391283"]].count);
}

- (void) assertCookieDomainExactMatching:(NSHTTPCookie*)cookie {

    [_cookiesStorage setCookie:cookie forURL:[NSURL URLWithString:@"http://readdle.com/success"]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/success"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com./must/be/good.html"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://ReAdDlE.com"]].count);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://enterprise.readdle.com/success"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://chineesreaddle.com/Mao"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.comm"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com.ua"]].count);

    [_cookiesStorage deleteAllCookies];
}

- (void) assertCookieDomainTailMatching:(NSHTTPCookie*)cookie {

    [_cookiesStorage setCookie:cookie forURL:[NSURL URLWithString:@"http://readdle.com/success"]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/success"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://enterprise.readdle.com/success"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://ANY.service.READDLE.com/success"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com./must/be/good.html"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://scanner.ReAdDlE.com"]].count);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://chineesreaddle.com/Mao"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.comm"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com.ua"]].count);

    [_cookiesStorage deleteAllCookies];
}

- (void) testCookieWithDomainIsTailMatching {
    [self assertCookieDomainTailMatching:[self cookieWithName:@"name1" value:@"value1" domain:@".readdle.com" expirationDate:nil]];
    [self assertCookieDomainTailMatching:[self cookieWithHTTPHeaderValue:@"name=value; domain=readdle.com" forURL:[NSURL URLWithString:@"http://readdle.com"]]];
}

- (void) testCookieWithoutDomainIsExactMatching {
    [self assertCookieDomainExactMatching:[self cookieWithName:@"name1" value:@"value1" domain:@"readdle.com" expirationDate:nil]];
    [self assertCookieDomainExactMatching:[self cookieWithHTTPHeaderValue:@"name=value" forURL:[NSURL URLWithString:@"http://readdle.com"]]];
}

- (void) testAddingCookieForTopLevelDomainForURL {
    NSURL * testURL = [NSURL URLWithString:@"http://readdle.com"];

    [_cookiesStorage setCookie:[self cookieWithName:@"name" value:@"value" domain:@"." expirationDate:nil] forURL:testURL];
    [_cookiesStorage setCookie:[self cookieWithName:@"name" value:@"value" domain:@"com" expirationDate:nil] forURL:testURL];
    [_cookiesStorage setCookie:[self cookieWithName:@"name" value:@"value" domain:@"com." expirationDate:nil] forURL:testURL];
    [_cookiesStorage setCookie:[self cookieWithName:@"name" value:@"value" domain:@".com" expirationDate:nil] forURL:testURL];
    [_cookiesStorage setCookie:[self cookieWithName:@"name" value:@"value" domain:@".com." expirationDate:nil] forURL:testURL];

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:testURL].count);
}

- (void) testSettingSubdomainCookiesIsRejected {
    NSURL * domainURL = [NSURL URLWithString:@"http://readdle.com"];
    NSHTTPCookie * cookie = [self cookieWithHTTPHeaderValue:@"name=value; domain=enterprise.readdle.com" forURL:domainURL];
    [_cookiesStorage setCookie:cookie forURL:domainURL];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:domainURL].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://enterprise.readdle.com"]].count);
}

- (void) testSettingOtherPathCookieIsNotRejected {
    // this is another shit of apple's cookies storage - it does not reject cookies with path not matching the URL path
    // this must be rejected according to rfc6265
    //
    NSHTTPCookie * cookie = [self cookieWithHTTPHeaderValue:@"name=value; path=/test;" forURL:[NSURL URLWithString:@"http://readdle.com/some/other/path"]];
    [_cookiesStorage setCookie:cookie forURL:[NSURL URLWithString:@"http://readdle.com/some/other/path"]];

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/test/path"]].count);
}

- (void) testPathMatching {
    NSURL * testURL = [NSURL URLWithString:@"http://readdle.com"];
    [_cookiesStorage setCookie:[self cookieWithHTTPHeaderValue:@"name=value;" forURL:testURL] forURL:testURL];
    [_cookiesStorage setCookie:[self cookieWithHTTPHeaderValue:@"name2=value2; path=/" forURL:testURL] forURL:testURL];
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://pastey:r1e2d3@readdle.com"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com:8080"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/some/path/to/document.pdf"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/some.file"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/index.php"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/search?q=scanner&ver=10.0"]].count);
    [_cookiesStorage deleteAllCookies];

    // path matching in NSHTTPCookieStorage is not rfc6265 section 5.1.4 compliant - it mathches "http://ya.ru/testfile.txt" for "/test" path

    [_cookiesStorage setCookie:[self cookieWithHTTPHeaderValue:@"name2=value2; path=/test" forURL:testURL] forURL:testURL];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://pastey:r1e2d3@readdle.com/test"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com:8080/test/file.pdf"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/test/path/to/document.pdf"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/testfile.txt"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/index.php"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/search?q=scanner&ver=10.0"]].count);
    [_cookiesStorage deleteAllCookies];

    [_cookiesStorage setCookie:[self cookieWithHTTPHeaderValue:@"name2=value2; path=/users/pastey/projects" forURL:testURL] forURL:testURL];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://pastey:r1e2d3@readdle.com/users/pastey/projects"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com:8080/users/pastey/projects/file.pdf"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/users/pastey/projects/path/to/document.pdf"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/users/pastey/projects/../../otherUser/secrets/photos/1.jpg"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/users/pastey/projectsfile.txt"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com:8080/users/pastey/music/thriller.mp3"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/index.php"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/search?q=scanner&ver=10.0"]].count);
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com:8080/USERS/pastey/projects/file.pdf"]].count);
    [_cookiesStorage deleteAllCookies];
}

- (void) testSubstituteExactCookie
{
    NSHTTPCookie * cookie1 = [self cookieWithName:@"name" value:@"value"];
    [_cookiesStorage setCookie:cookie1 forURL:[self testURL]];

    NSHTTPCookie * cookie2 = [self cookieWithName:@"name" value:@"value2"];
    [_cookiesStorage setCookie:cookie2 forURL:[self testURL]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");
    XCTAssertEqualObjects(cookie2, [_cookiesStorage cookiesForURL:[self testURL]].firstObject, @"cookie must be equal!");
}

- (void) testSubstituteTailmatchCookie
{
    NSHTTPCookie * cookie1 = [self cookieWithHTTPHeaderValue:@"name=value1; domain=readdle.com." forURL:[NSURL URLWithString:@"http://alpha.readdle.com/"]];
    [_cookiesStorage setCookie:cookie1 forURL:[NSURL URLWithString:@"http://alpha.readdle.com/"]];

    NSHTTPCookie * cookie2 = [self cookieWithHTTPHeaderValue:@"name=value2; domain=.reAddle.com" forURL:[NSURL URLWithString:@"http://beta.readdle.com/"]];
    [_cookiesStorage setCookie:cookie2 forURL:[NSURL URLWithString:@"http://beta.readdle.com/"]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/"]].count);
    XCTAssertEqualObjects(cookie2, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/"]].firstObject);

    NSHTTPCookie * cookie3 = [self cookieWithHTTPHeaderValue:@"name=value2; domain=readdle.COM" forURL:[NSURL URLWithString:@"http://readdle.com/"]];
    [_cookiesStorage setCookie:cookie3 forURL:[NSURL URLWithString:@"http://readdle.com/"]];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/"]].count);
    XCTAssertEqualObjects(cookie3, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/"]].firstObject);
}

- (void) testSubstituteCookieDoesNotMessExactAndTailMatchDomains
{
    NSURL * testURL = [NSURL URLWithString:@"http://readdle.com/"];
    NSHTTPCookie * cookie1 = [self cookieWithHTTPHeaderValue:@"name=value1;" forURL:testURL];
    [_cookiesStorage setCookie:cookie1 forURL:testURL];

    NSHTTPCookie * cookie2 = [self cookieWithHTTPHeaderValue:@"name=value2; domain=readdle.com" forURL:testURL];
    [_cookiesStorage setCookie:cookie2 forURL:testURL];

    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:testURL].count, @"there must be 2 cookies: one exactly for domain and the other for all subdomains");
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://beta.readdle.com/"]].count);
}

- (void) testCookieWithSameNameDoesNotSubstituteForDifferentPath {
    NSURL * testURL = [NSURL URLWithString:@"http://readdle.com/"];

    NSHTTPCookie * cookie1 = [self cookieWithHTTPHeaderValue:@"name1=value1; path=/" forURL:testURL];
    [_cookiesStorage setCookie:cookie1 forURL:testURL];

    NSHTTPCookie * cookie2 = [self cookieWithHTTPHeaderValue:@"name1=value2; path=/other" forURL:testURL];
    [_cookiesStorage setCookie:cookie2 forURL:testURL];

    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/other/doc.pdf"]].count);
}

- (void) testCookieWithSameNameSubstitutesForSamePath {
    NSURL * testURL = [NSURL URLWithString:@"http://readdle.com/other/doc.pdf"];

    NSHTTPCookie * cookie1 = [self cookieWithHTTPHeaderValue:@"name1=value1; path=/other" forURL:testURL];
    [_cookiesStorage setCookie:cookie1 forURL:testURL];

    NSHTTPCookie * cookie2 = [self cookieWithHTTPHeaderValue:@"name1=value2; path=/other" forURL:testURL];
    [_cookiesStorage setCookie:cookie2 forURL:testURL];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com/other/doc.pdf"]].count);
}


- (void)testRemovePersistantCookieBySettingExpirationDateInPast
{
    NSHTTPCookie * distantFutureExireCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate distantFuture]];
    [_cookiesStorage setCookie:distantFutureExireCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");

    NSHTTPCookie * distantPastExpiredCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate distantPast]];
    [_cookiesStorage setCookie:distantPastExpiredCookie forURL:[self testURL]];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void)testRemoveSessionCookieBySettingExpirationDateInPast
{
    NSHTTPCookie * sessionCookie = [self cookieWithName:@"name" value:@"value"];
    [_cookiesStorage setCookie:sessionCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    NSHTTPCookie * distantPastExpiredCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate distantPast]];
    [_cookiesStorage setCookie:distantPastExpiredCookie forURL:[self testURL]];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void)testRemoveSessionCookieBySettingExpirationDateInPastButOtherDomainOrPath
{
    NSHTTPCookie * originalCookie = [self cookieWithHTTPHeaderValue:@"name=value; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:[self testURL]];
    [_cookiesStorage setCookie:originalCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);

    NSHTTPCookie * expiredCookieForOtherDomain = [self cookieWithHTTPHeaderValue:@"name=value2; Expires=Fri, 13 Sep 1985 07:15:00 GMT" forURL:[NSURL URLWithString:@"http://some.other.domain"]];
    [_cookiesStorage setCookie:expiredCookieForOtherDomain forURL:[NSURL URLWithString:@"http://some.other.domain"]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);

    NSHTTPCookie * expiredCookieForOtherPath = [self cookieWithHTTPHeaderValue:@"name=value3; Expires=Fri, 13 Sep 1985 07:15:00 GMT; path=/other/path" forURL:[self testURL]];
    [_cookiesStorage setCookie:expiredCookieForOtherPath forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);

    XCTAssertEqualObjects(originalCookie, [[_cookiesStorage cookiesForURL:[self testURL]] firstObject]);
}

- (void) testCookieExpires {
    NSHTTPCookie * cookieThatExpiresInASecond = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate dateWithTimeInterval:.5 sinceDate:[NSDate date]]];
    
    [_cookiesStorage setCookie:cookieThatExpiresInASecond forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    sleep(1);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testSetOfCookieThatIsExpired {
    NSHTTPCookie * expiredCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate distantPast]];
    [_cookiesStorage setCookie:expiredCookie forURL:[self testURL]];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testCookieExpiresViaMaxAge {
    NSHTTPCookie * cookieThatExpiresInASecond = [self cookieWithHTTPHeaderValue:@"name=value; Max-Age=1" forURL:[self testURL]];
    [_cookiesStorage setCookie:cookieThatExpiresInASecond forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    sleep(2);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testSetOfCookieThatIsExpiredViaMaxAge {
    NSHTTPCookie * expiredCookie = [self cookieWithHTTPHeaderValue:@"name=value; Max-Age=-1" forURL:[self testURL]];
    [_cookiesStorage setCookie:expiredCookie forURL:[self testURL]];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testSetOfCookieThatExpiresWithZeroMaxAge {
    // spec says that 0 max age must behave like < 0 but NSHTTPCookie knows better -
    // it sets Expires to either the same second or the next second
    // it simply rounds current second value.
    // for example:
    // date of cookie parsing 402498287.157108 - date of expiration 402498287.000000
    // date of cookie parsing 402498287.752195 - date of expiration 402498288.000000
    NSHTTPCookie * cookieThatExpiresInZeroSeconds = [self cookieWithHTTPHeaderValue:@"name=value; Max-Age=0" forURL:[self testURL]];
    [_cookiesStorage setCookie:cookieThatExpiresInZeroSeconds forURL:[self testURL]];

    sleep(1);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testMaxAgeTakesPrecidanceOverExpires {
    NSHTTPCookie * expiresInTenSecondsCookie = [self cookieWithHTTPHeaderValue:@"name=value; Max-Age=10; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:[self testURL]];
    const NSTimeInterval expiresIn = [[expiresInTenSecondsCookie expiresDate] timeIntervalSinceReferenceDate] - [[NSDate date] timeIntervalSinceReferenceDate];
    const BOOL expiresInTenSeconds = expiresIn > 9.0 && expiresIn < 11.0;
    XCTAssertTrue(expiresInTenSeconds);

    NSHTTPCookie * expiredCookie = [self cookieWithHTTPHeaderValue:@"name=value; Max-Age=-10; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:[self testURL]];
    const BOOL expired = ([[expiredCookie expiresDate] timeIntervalSinceReferenceDate] - [[NSDate date] timeIntervalSinceReferenceDate]) < 0;
    XCTAssertTrue(expired);
}

- (void) testSessionOnlyCookiesAreRemovedOnRelaunch {
    NSHTTPCookie * sessionCookie = [self cookieWithName:@"name" value:@"value"];
    [_cookiesStorage setCookie:sessionCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    [_cookiesStorage release];
    _cookiesStorage = [self newCookiesStorage];

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testPersistentCookiesAreSavedOnRelaunch {
    NSHTTPCookie * persistentCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate distantFuture]];
    [_cookiesStorage setCookie:persistentCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    [_cookiesStorage release];
    _cookiesStorage = [self newCookiesStorage];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
    XCTAssertEqualObjects(persistentCookie, [_cookiesStorage cookiesForURL:[self testURL]].firstObject, @"");
}

- (void) testPersistentCookiesAreSavedOnRelaunchAndExpire {
    NSHTTPCookie * persistentCookie = [self cookieWithName:@"name" value:@"value" expirationDate:[NSDate dateWithTimeInterval:0.5 sinceDate:[NSDate date]]];
    [_cookiesStorage setCookie:persistentCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");

    [_cookiesStorage release];
    _cookiesStorage = [self newCookiesStorage];

    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookies!");
    XCTAssertEqualObjects(persistentCookie, [_cookiesStorage cookiesForURL:[self testURL]].firstObject, @"");

    sleep(1);

    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain NO cookies!");
}

- (void) testPersistentCookiesSaveAllAttributes {
    NSURL * testURL = [NSURL URLWithString:@"https://example.com/mega/path/test"];
    NSHTTPCookie * persistentCookie1 = [self cookieWithHTTPHeaderValue:@"SUID=0x234df33; secure; path=/mega/path; domain=.example.com; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:testURL];
    [_cookiesStorage setCookie:persistentCookie1 forURL:[self testURL]];
    NSHTTPCookie * persistentCookie2 = [self cookieWithHTTPHeaderValue:@"hi=hello; path=/mega/path; domain=.example.com; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:testURL];
    [_cookiesStorage setCookie:persistentCookie2 forURL:[self testURL]];
    NSHTTPCookie * persistentCookie3 = [self cookieWithHTTPHeaderValue:@"lang=en_US; path=/mega; Expires=Wed, 09 Jun 2021 10:18:14 GMT" forURL:testURL];
    [_cookiesStorage setCookie:persistentCookie3 forURL:[self testURL]];

    XCTAssertEqual(3u, [_cookiesStorage cookiesForURL:testURL].count);

    [_cookiesStorage release];
    _cookiesStorage = [self newCookiesStorage];

    XCTAssertEqual(3u, [_cookiesStorage cookiesForURL:testURL].count);
    XCTAssertTrue([[_cookiesStorage cookiesForURL:testURL] containsObject:persistentCookie1]);
    XCTAssertTrue([[_cookiesStorage cookiesForURL:testURL] containsObject:persistentCookie2]);
    XCTAssertTrue([[_cookiesStorage cookiesForURL:testURL] containsObject:persistentCookie3]);
}

- (void) testCookiesSortOrder {
    NSURL * testURL = [NSURL URLWithString:@"https://example.com/mega/path/test"];
    NSHTTPCookie * cookieWithMiddlePath = [self cookieWithHTTPHeaderValue:@"middle=value; path=/mega/path/t" forURL:testURL];
    NSHTTPCookie * cookieWithShortPath1  = [self cookieWithHTTPHeaderValue:@"short1=value; path=/mega/path" forURL:testURL];
    NSHTTPCookie * cookieWithShortPath2  = [self cookieWithHTTPHeaderValue:@"short2=value; path=/mega/path" forURL:testURL];
    NSHTTPCookie * cookieWithLongPath   = [self cookieWithHTTPHeaderValue:@"long=value; path=/mega/path/test" forURL:testURL];

    [_cookiesStorage setCookie:cookieWithShortPath2 forURL:testURL];
    [_cookiesStorage setCookie:cookieWithMiddlePath forURL:testURL];
    [_cookiesStorage setCookie:cookieWithShortPath1 forURL:testURL];
    [_cookiesStorage setCookie:cookieWithLongPath forURL:testURL];

    NSArray * excpectedCookiesOrder = @[ cookieWithLongPath, cookieWithMiddlePath, cookieWithShortPath2, cookieWithShortPath1 ];
    // NOTE:
    // creation date property of NSHTTPCookie is private, neither it implements compare: method
    // that's why our impl of cookies storage sorts same length path cookies by the time cookie was added to storage,
    // and in this aspect we will work different from NSHTTPCookiesStorage
    //
    XCTAssertEqualObjects([_cookiesStorage cookiesForURL:testURL], excpectedCookiesOrder);
}

- (void) testCookieWithEmptyValue {
    NSHTTPCookie * sessionCookie = [self cookieWithName:@"name" value:@""];
    [_cookiesStorage setCookie:sessionCookie forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count, @"cookies storage must contain 1 cookie!");
}

- (void) testCookieWithEmptyName {
    // NSHTTPCookie with empty name can't be created, so there's no test case for empty name
    // if creating cookie with empty name was possible we would have to ignore such cookies
    // according to rfc6265
    //
    XCTAssertNil([self cookieWithName:@"" value:@"value"]);
}

- (void) testCookieWithProhibitedSymbolsInValue {
    // according to rfc "CTLs, whitespace, DQUOTE, comma, semicolon, and backslash" are prohibited,
    // but NSHTTPCookiesStorage accepts them, so we will accept them too.
    // This is shitty place, I've checked what Chrome does with this symbols - it truncates value as soon as he encounters such symbols
    //
    NSHTTPCookie * cookieWithComma = [self cookieWithName:@"name" value:@"value,"];
    [_cookiesStorage setCookie:cookieWithComma forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    [_cookiesStorage deleteAllCookies];

    NSHTTPCookie * cookieWithSemicolomn = [self cookieWithName:@"name" value:@"value;"];
    [_cookiesStorage setCookie:cookieWithSemicolomn forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    [_cookiesStorage deleteAllCookies];

    //
    NSHTTPCookie * cookieWithBackslash = [self cookieWithName:@"name" value:@"value\\"];
    [_cookiesStorage setCookie:cookieWithBackslash forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    [_cookiesStorage deleteAllCookies];

    NSHTTPCookie * cookieWithDquote = [self cookieWithName:@"name" value:@"value\""];
    [_cookiesStorage setCookie:cookieWithDquote forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    [_cookiesStorage deleteAllCookies];

    NSHTTPCookie * cookieWithSpace = [self cookieWithName:@"name" value:@"  value with space        "];
    [_cookiesStorage setCookie:cookieWithSpace forURL:[self testURL]];
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[self testURL]].count);
    [_cookiesStorage deleteAllCookies];
}

- (void) testSecureAttribute {
    NSURL * testURL = [NSURL URLWithString:@"https://readdle.com"];
    [_cookiesStorage setCookie:[self cookieWithHTTPHeaderValue:@"name=value; Secure;" forURL:testURL] forURL:testURL];
    XCTAssertEqual(0u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://readdle.com"]].count);
    XCTAssertEqual(1u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"https://readdle.com"]].count);
}

- (void) testCookieNameAndValueSizeLimits {
    // This test ensures that we won't allow cookies with too big value or name sizes.
    // As this test asserts, this check is made by NSHTTPCookie for us - it won't create if:
    //  - name length > 4091
    //  - value length > 4092
    //
    // I have checked the rest of attributes - domain and path are not checked for sanity - they can take Mb and NSHTTPCookie is happy
    // this is piece of shit, as for me.
    //

    NSMutableString * madString = [NSMutableString new];
    for (NSUInteger i=0; i<4093; ++i) {
        [madString appendString:@"a"];
    }

    NSHTTPCookie * cookieWithMadName = [self cookieWithName:madString value:@"value"];
    XCTAssertNil(cookieWithMadName);
    cookieWithMadName = [self cookieWithHTTPHeaderValue:[NSString stringWithFormat:@"%@=value", madString] forURL:[self testURL]];
    XCTAssertNil(cookieWithMadName);
    NSHTTPCookie * cookieWithMadValue = [self cookieWithName:@"name" value:madString];
    XCTAssertNil(cookieWithMadValue);
    cookieWithMadValue = [self cookieWithHTTPHeaderValue:[NSString stringWithFormat:@"name=%@", madString] forURL:[self testURL]];
    XCTAssertNil(cookieWithMadValue);
    NSHTTPCookie * cookieWithMadPath = [self cookieWithHTTPHeaderValue:[NSString stringWithFormat:@"name=value; path=/%@", madString] forURL:[self testURL]];
    XCTAssertNotNil(cookieWithMadPath);
    NSHTTPCookie * cookieWithMadDomain = [self cookieWithHTTPHeaderValue:[NSString stringWithFormat:@"name=value; domain=%@.example.com", madString] forURL:[self testURL]];
    XCTAssertNotNil(cookieWithMadDomain);
}

- (void) testCookiesNumberLimit {
    // I've also checked at really crazy amounts - it does not care - adds all we ask it
    const NSUInteger crazyCookiesCount = 1024;

    for (NSUInteger i = 0; i < crazyCookiesCount; ++i) {
        NSString * name = [NSString stringWithFormat:@"name%@", @(i)];
        NSHTTPCookie * cookie = [self cookieWithName:name value:@"value" expirationDate:[NSDate distantFuture]];
        [_cookiesStorage setCookie:cookie forURL:[self testURL]];
    }

    XCTAssertEqual([_cookiesStorage cookiesForURL:[self testURL]].count, crazyCookiesCount);
}

- (void) testPortsAreNotTakenIntoAccountWhenGettingCookiesForURL {
    NSHTTPCookie * cookieForOnePort = [self cookieWithHTTPHeaderValue:@"forPort1=value;" forURL:[NSURL URLWithString:@"http://example.com:8000/test"]];
    NSHTTPCookie * cookieForTheOtherPort = [self cookieWithHTTPHeaderValue:@"forPort2=value;" forURL:[NSURL URLWithString:@"http://example.com:8001/go"]];
    [_cookiesStorage setCookie:cookieForOnePort forURL:[NSURL URLWithString:@"http://example.com/"]];
    [_cookiesStorage setCookie:cookieForTheOtherPort forURL:[NSURL URLWithString:@"http://example.com/"]];

    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://example.com/"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://example.com:8000/"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"http://example.com:8001/"]].count);
    XCTAssertEqual(2u, [_cookiesStorage cookiesForURL:[NSURL URLWithString:@"https://example.com:443/"]].count);
}

@end
