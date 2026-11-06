// SPDX-FileCopyrightText: 2026 Kerrick Long <me@kerricklong.com>
// SPDX-License-Identifier: MIT-0
//
// The app's entry point when SDL3 owns the screen (Fledge's ADR 025), in
// place of the Host/main.m fledge build writes. SDL_RunApp starts UIKit
// with SDL's own delegates (src/video/uikit/SDL_uikitappdelegate.m at
// release-3.4.10, lines 43 to 64), and once the scene connects calls
// run_ruby on the main thread, inside the run loop (lines 354 to 420 and
// 481 to 489), where SDL's video must run. run_ruby runs the app's Ruby
// program there, with FledgeRuby's fledge_ruby_run_app, as Fledge's host
// does on a thread of its own, so Ruby can call SDL directly. The main
// thread's stack is the one the executable asks for, with -Wl,-stack_size
// in OTHER_LDFLAGS. Info.plist names SDLUIKitSceneDelegate as the scene's
// delegate.
//
// Dot Popper's copy (doc/ios.md) is Lota 0.2.2's (ext/lota/phone/host/ios
// in the gem), which kits.yml lays it over in the phone project, with one
// addition: the colour behind SDL's view, on its window and the window's
// root view, as each window becomes key: the night's ink (#0c0b22), so
// nothing pink or white can show behind the game, or, with
// DOT_POPPER_DIAGNOSTIC_COLORS set, pure green, so that a strip the game
// does not cover shows as green (doc/ios.md, "Diagnostic colours").
// Lota's host already sets the audio session to Ambient (Info.plist's
// LotaAudioSessionCategory) and SDL_ACCELEROMETER_AS_JOYSTICK=0.
@import FledgeRuby;
@import AVFoundation;
@import Foundation;
@import UIKit;

#include <errno.h>
#include <os/log.h>
#include <stdlib.h>
#include <string.h>

// SDL_main.h's SDL_main_func and SDL_RunApp, from SDL3, which the app's
// gem links in; declared here so the host needs no SDL headers.
typedef int (*SDL_main_func)(int argc, char *argv[]);
extern int SDL_RunApp(int argc, char *argv[], SDL_main_func main_function, void *reserved);

static os_log_t app_log;

static NSString *AppName(void) {
  NSDictionary *info = NSBundle.mainBundle.infoDictionary;
  return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
}

// What shows behind SDL's view: the night's ink, or green to diagnose.
static UIColor *BackdropColor(void) {
  if (getenv("DOT_POPPER_DIAGNOSTIC_COLORS"))
    return [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
  return [UIColor colorWithRed:0x0c / 255.0 green:0x0b / 255.0 blue:0x22 / 255.0 alpha:1.0];
}

// Whether +view+, or a view inside it, draws with Metal: SDL's view.
static BOOL draws_with_metal(UIView *view) {
  if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")])
    return YES;
  for (UIView *subview in view.subviews)
    if (draws_with_metal(subview))
      return YES;
  return NO;
}

// Paints +window+, its root view, and the root view's layer, if it is
// SDL's window. Other windows are left alone: on an iPad, iOS shows
// windows of its own above SDL's, and one painted opaque hid the game.
static void paint_behind(UIWindow *window) {
  if (![window isKindOfClass:UIWindow.class] || !draws_with_metal(window))
    return;
  UIColor *color = BackdropColor();
  window.backgroundColor = color;
  UIView *root = window.rootViewController.view;
  root.backgroundColor = color;
  root.layer.backgroundColor = color.CGColor;
}

// Paints each window as it becomes key or visible, which SDL's are once
// it has made them.
static void watch_windows(void) {
  NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
  for (NSNotificationName name in @[ UIWindowDidBecomeKeyNotification, UIWindowDidBecomeVisibleNotification ]) {
    [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
      paint_behind(note.object);
    }];
  }
}

// SDL's main function: runs the app's Ruby program on the calling thread,
// the main thread, and logs its exit status.
static int run_ruby(int argc, char *argv[]) {
  NSString *root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"fledge"];
  int status = fledge_ruby_run_app(root.fileSystemRepresentation, 0, NULL);
  os_log(app_log, "%{public}@ exited with status %d", AppName(), status);
  return status;
}

// The audio session's category, from Info.plist's LotaAudioSessionCategory:
// ambient mixes with other apps' audio and the silent switch mutes it,
// soloAmbient (the system's default) stops other apps' audio and the
// switch mutes it, playback stops other apps' audio and plays through
// the switch. Empty or missing leaves the system's default.
static AVAudioSessionCategory AudioCategory(void) {
  NSString *name = NSBundle.mainBundle.infoDictionary[@"LotaAudioSessionCategory"];
  if ([name isEqualToString:@"ambient"])
    return AVAudioSessionCategoryAmbient;
  if ([name isEqualToString:@"soloAmbient"])
    return AVAudioSessionCategorySoloAmbient;
  if ([name isEqualToString:@"playback"])
    return AVAudioSessionCategoryPlayback;
  if (name.length > 0)
    os_log_error(app_log, "unknown LotaAudioSessionCategory %{public}@, kept the default", name);
  return nil;
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
    app_log = os_log_create(identifier.UTF8String, "app");
    // The unified log copies every entry to standard error when the
    // environment holds OS_ACTIVITY_DT_MODE, whatever its value, as
    // Xcode's console and XCTest set it. Forwarding standard error to
    // the log would then loop on the app's own output and freeze it,
    // so the streams stay with the tool that launched the app, whose
    // console shows them. Fledge's fledge_ruby_forward_output makes the
    // same check since 0.5.0 (its runtime/mobile/apple.c); the host
    // says so in the log, where the app's lines would otherwise be.
    if (getenv("OS_ACTIVITY_DT_MODE") != NULL) {
      os_log(app_log, "OS_ACTIVITY_DT_MODE is set, so the app's output stays on its own streams");
    } else if (fledge_ruby_forward_output(identifier.UTF8String) != 0) {
      os_log_error(app_log, "could not send the app's output to the log: %{public}s",
                   strerror(errno));
    }
    // A guard, not LÖVE's behavior: on iOS SDL makes the accelerometer
    // a joystick by default (SDL_HINT_ACCELEROMETER_AS_JOYSTICK, which
    // SDL also reads from this environment variable), and LÖVE leaves
    // it so. An early Lota crashed in the iPad Simulator while a game
    // read that joystick every frame, so the host hides it: a game reads
    // the accelerometer through Lota::Sensor, and a paired controller
    // is still a joystick. The environment wins, so a scheme's
    // SDL_ACCELEROMETER_AS_JOYSTICK=1 brings the joystick back.
    setenv("SDL_ACCELEROMETER_AS_JOYSTICK", "0", 0);
    AVAudioSessionCategory category = AudioCategory();
    NSError *error = nil;
    if (category != nil && ![AVAudioSession.sharedInstance setCategory:category error:&error]) {
      os_log_error(app_log, "could not set the audio session's category: %{public}@", error);
    }
    watch_windows();
  }
  return SDL_RunApp(argc, argv, run_ruby, NULL);
}
