// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// A bare app to host StoreCheckTests. It declares DotPopperStore and calls
// it just as Host/main.m does, so this project's build also proves that an
// Objective-C main links to Store.swift's class.
@import Foundation;
@import UIKit;

@interface DotPopperStore : NSObject
+ (BOOL)handleURL:(NSURL *)url;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate {
  UIWindow *_window;
}

// A window on screen, as the game has: StoreKit's purchase looks for one.
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  _window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  _window.rootViewController = [UIViewController new];
  [_window makeKeyAndVisible];
  return YES;
}
@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    // A URL that isn't the store's is refused, and the class is linked in.
    [DotPopperStore handleURL:[NSURL URLWithString:@"https://example.com/"]];
    return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class));
  }
}
