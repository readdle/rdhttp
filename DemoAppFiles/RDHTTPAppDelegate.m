//
//  RDHTTPAppDelegate.m
//  RDHTTP
//
//  Created by Andrian Budantsov on 26.11.11.
//  Copyright (c) 2011 Readdle. All rights reserved.
//

#import <pthread.h>
#import "RDHTTPAppDelegate.h"
#import "RDHTTPDemoRoot.h"
@implementation RDHTTPAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

    RDHTTPDemoRoot *demoRoot = [RDHTTPDemoRoot new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:demoRoot];
    self.window.rootViewController = nav;
    [nav release];
    [demoRoot release];

    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    NSLog(@"Starting custom thread for HTTP processing");
    NSThread *customHTTPThread = [[NSThread alloc] initWithTarget:self selector:@selector(httpThreadMain) object:nil];
    [RDHTTPOperation setThread:customHTTPThread];
    [customHTTPThread start];
    [customHTTPThread release];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)httpThreadMain {
    @autoreleasepool {
        [NSThread currentThread].name = @"RDHTTPDemoConnectionThread";
        pthread_setname_np("RDHTTPDemoConnectionThread");
        [NSTimer scheduledTimerWithTimeInterval:1000000 target:[NSNull null] selector:@selector(description) userInfo:nil repeats:YES];

        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        BOOL hasSources = YES;

        while(![NSThread currentThread].isCancelled && hasSources) {
            @autoreleasepool {
                hasSources = [loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
            }
        }
    }
}

@end
