// Dot Popper's iOS entry point, which `fledge build ios` lays over the
// Host/main.m it writes (fledge.yml's ios host, as kits.yml writes it). It
// is Fledge 0.5.0's examples/sdl_phone/host/ios/Host/main.m (MIT-0), in
// which SDL3 owns the screen: SDL_RunApp starts UIKit with SDL's own
// delegates and, once the scene connects, calls run_ruby on the main
// thread, inside the run loop, where SDL's video must run. run_ruby runs
// the app's Ruby program there with FledgeRuby's fledge_ruby_run_app. The
// main thread's stack is the one the executable asks for, with
// -Wl,-stack_size in project.yml. Info.plist names SDLUIKitSceneDelegate as
// the scene's delegate.
//
// Dot Popper adds two settings before SDL starts (doc/ios.md):
// - the audio session's category, Ambient, so the game's sound mixes with
//   other apps' and the silent switch mutes it;
// - SDL_ACCELEROMETER_AS_JOYSTICK=0, so SDL does not present the iPad's
//   accelerometer as a joystick: the game reads tilt through Lota::Sensor,
//   and a joystick that is no gamepad is only something more to go wrong.
//
// Fledge 0.5.0's runtime leaves the app's output on its own streams when
// OS_ACTIVITY_DT_MODE is set (its CHANGELOG), so the host needs no check
// of its own for it.
@import FledgeRuby;
@import AVFoundation;
@import Foundation;

#include <errno.h>
#include <os/log.h>
#include <stdlib.h>
#include <string.h>

// SDL_main.h's SDL_main_func and SDL_RunApp, from SDL3, which Lota's
// engine links in; declared here so the host needs no SDL headers.
typedef int (*SDL_main_func)(int argc, char *argv[]);
extern int SDL_RunApp(int argc, char *argv[], SDL_main_func main_function, void *reserved);

static os_log_t app_log;

static NSString *AppName(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    return info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"];
}

// SDL's main function: runs the app's Ruby program on the calling thread,
// the main thread, and logs its exit status.
static int run_ruby(int argc, char *argv[]) {
    NSString *root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"fledge"];
    int status = fledge_ruby_run_app(root.fileSystemRepresentation, 0, NULL);
    os_log(app_log, "%{public}@ exited with status %d", AppName(), status);
    return status;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
        app_log = os_log_create(identifier.UTF8String, "app");
        if (fledge_ruby_forward_output(identifier.UTF8String) != 0) {
            os_log_error(app_log, "could not send the app's output to the log: %{public}s", strerror(errno));
        }
        setenv("SDL_ACCELEROMETER_AS_JOYSTICK", "0", 1);
        NSError *error = nil;
        if (![AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryAmbient error:&error]) {
            os_log_error(app_log, "could not set the audio session's category: %{public}@", error);
        }
    }
    return SDL_RunApp(argc, argv, run_ruby, NULL);
}
