//
//  URBAppDelegate.m
//  URBFlipModalViewControllerDemo
//
//  Created by Nicholas Shipes on 12/20/12.
//  Copyright (c) 2012 Urban10 Interactive. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "URBAlertView.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	UIViewController *rootController = [[ViewController alloc] initWithNibName:nil bundle:nil];
	self.window.rootViewController = rootController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
