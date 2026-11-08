// SPDX-FileCopyrightText: 2026 setdef <kerrick@setdef.com>
// SPDX-License-Identifier: AGPL-3.0-or-later

package org.setdef.fledge.host;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.system.ErrnoException;
import android.system.Os;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Display;
import android.view.DisplayCutout;
import android.view.WindowManager;
import android.window.OnBackInvokedDispatcher;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.libsdl.app.SDLActivity;
import org.setdef.fledge.FledgeRuby;

/**
 * A Lota game's screen on Android, in place of the MainActivity that
 * fledge build android writes, under the same name, so Fledge's manifest
 * and Gradle files find it (Fledge's ADR 025, and its
 * examples/sdl_phone/host/android). It is SDL's Activity: it loads
 * libSDL3.so first, whose JNI_OnLoad registers SDL's Java methods, then
 * OpenAL Soft's libopenal.so, Fledge's Ruby, and libfledgeext.so, which
 * holds Lota's engine and extension, and runs the app's Ruby program from
 * SDL's main function, on a thread with FledgeRuby's 64 MB stack that
 * SDL's thread waits for, so the game ends when Ruby does.
 *
 * LÖVE's engine calls methods of love-android's GameActivity through JNI
 * (vendor/love/src/common/android.cpp) without checking that they exist:
 * setImmersiveMode from every love.window.setMode, getDPIScale for the
 * window's scale, and the others below. This class has them, as
 * GameActivity does.
 *
 * SDL's own Java classes (org.libsdl.app, beside this one) are SDL
 * 3.4.10's, unchanged: SDLActivity refuses a libSDL3.so of another
 * release, and rake android:deps builds 3.4.10's (tasks/android_build.rb).
 *
 * Dot Popper's copy (PACKAGING.md, "The Android kit") is Lota 0.2.2's
 * (ext/lota/phone/host/android in the gem) with four changes. In a
 * debuggable build only, each string extra of the launching intent named
 * lota.env.NAME sets the environment variable NAME before Ruby starts, so
 * the emulator checks can pass the game its settings with am start --es.
 * Share my score opens Android's share sheet: the game opens a
 * dotpopper-share: URL (SheetSharing), and startActivity, below, starts
 * the sheet in its place. The window asks for the screen's fastest
 * refresh rate (preferFastestRefresh). And vibrate buzzes from a thread
 * of its own, so the game's thread never waits for the vibrator.
 */
public class MainActivity extends SDLActivity {
    private static final String ENV_PREFIX = "lota.env.";

    // The scheme the game opens to share a result (SheetSharing::SCHEME),
    // and the query parameter that holds the text.
    private static final String SHARE_SCHEME = "dotpopper-share";
    private static final String SHARE_TEXT = "text";

    // The meta-data in AndroidManifest.xml that asks SDL to send Back to
    // the game as a key and do nothing else (SDL's SDL_HINT_ANDROID_TRAP_BACK_BUTTON).
    private static final String TRAP_BACK = "SDL_ENV.SDL_ANDROID_TRAP_BACK_BUTTON";

    private Vibrator vibrator;
    // Where each buzz is started: Vibrator.vibrate asks the system's
    // vibrator service and waits for it, 1 to 5 ms on a OnePlus Nord, and
    // LÖVE calls vibrate on the game's own thread, so every pop cost the
    // game a frame at 120 Hz. One thread keeps the buzzes in order.
    private final ExecutorService buzzer = Executors.newSingleThreadExecutor();
    private boolean shortEdgesMode;

    @Override
    protected String[] getLibraries() {
        return new String[] {"SDL3", "openal", "fledgeruby", "fledgeext"};
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        if (checkSelfPermission(Manifest.permission.VIBRATE) == PackageManager.PERMISSION_GRANTED) {
            vibrator = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
        }
        super.onCreate(savedInstanceState);
        trapPredictiveBack();
        preferFastestRefresh();
        // SPDX-SnippetBegin
        // SPDX-SnippetCopyrightText: 2006-2024 LOVE Development Team
        // SPDX-License-Identifier: Zlib
        // love-android's GameActivity.onCreate (app/src/main/java/org/love2d/android/GameActivity.java at
        // 1c89bb0b2e, lines 117-121).
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams attr = getWindow().getAttributes();
            attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
            shortEdgesMode = false;
        }
        // SPDX-SnippetEnd
    }

    @Override
    protected void main() {
        String tag = getPackageName();
        CharSequence name = getApplicationInfo().loadLabel(getPackageManager());
        setEnvironmentFromIntent(tag);
        Thread ruby = FledgeRuby.startApp(this, "fledge.zip", new String[0], status -> Log.i(tag, name + " exited with status " + status));
        try {
            ruby.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /**
     * SDL traps Back in onBackPressed when the manifest's meta-data sets
     * TRAP_BACK to 1, but an app that targets API 36 gets predictive back,
     * where the system's own callback takes Back and closes the activity
     * without calling onBackPressed (an API 36 emulator did, after the game
     * had its escape key). So when the manifest asks for the trap, a
     * callback that does nothing takes Back's place, and the game alone
     * decides what Back does, from the key SDL still sends. Without the
     * meta-data, Back reaches the game as the key escape and then closes
     * the app, as in LÖVE. Whether a back gesture on Android 16, rather
     * than a Back key, still sends the game its key has not been tried.
     */
    private void trapPredictiveBack() {
        if (Build.VERSION.SDK_INT < 33) {
            return;
        }
        try {
            Bundle meta = getPackageManager().getApplicationInfo(getPackageName(), PackageManager.GET_META_DATA).metaData;
            if (meta == null || !"1".equals(String.valueOf(meta.get(TRAP_BACK)))) {
                return;
            }
        } catch (PackageManager.NameNotFoundException e) {
            return;
        }
        getOnBackInvokedDispatcher().registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, () -> {});
    }

    /**
     * Asks Android for the screen's fastest refresh rate at its present
     * resolution, such as 120 Hz on a OnePlus Nord N30, where a game's
     * window otherwise gets 60. The game draws with vsync, so it then draws
     * a frame for every refresh. The system still decides: the player's
     * own refresh rate setting, battery saver, and the maker's own rules
     * can each hold the screen slower.
     */
    private void preferFastestRefresh() {
        Display display = getWindowManager().getDefaultDisplay();
        Display.Mode current = display.getMode();
        Display.Mode fastest = current;
        for (Display.Mode mode : display.getSupportedModes()) {
            boolean sameSize = mode.getPhysicalWidth() == current.getPhysicalWidth()
                && mode.getPhysicalHeight() == current.getPhysicalHeight();
            if (sameSize && mode.getRefreshRate() > fastest.getRefreshRate()) {
                fastest = mode;
            }
        }
        WindowManager.LayoutParams attr = getWindow().getAttributes();
        attr.preferredDisplayModeId = fastest.getModeId();
        getWindow().setAttributes(attr);
        Log.i(getPackageName(), "asked for " + fastest.getRefreshRate() + " Hz");
    }

    /**
     * SDL_OpenURL starts an ACTION_VIEW intent for the URL through this
     * activity (SDLActivity.openURL), so a share URL is caught here and
     * never leaves the app: no other app is asked, and no activity of
     * ours needs an intent filter that other apps could reach. The share
     * sheet, a chooser over ACTION_SEND with the text as plain text,
     * starts in its place. A URL with no text throws, as an unknown URL
     * would, and SDL answers false, so the game falls back on its own
     * preview.
     */
    @Override
    public void startActivity(Intent intent) {
        Uri uri = intent.getData();
        if (!Intent.ACTION_VIEW.equals(intent.getAction()) || uri == null || !SHARE_SCHEME.equalsIgnoreCase(uri.getScheme())) {
            super.startActivity(intent);
            return;
        }
        String text = uri.getQueryParameter(SHARE_TEXT);
        if (text == null) {
            throw new IllegalArgumentException("a share URL with no text");
        }
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("text/plain");
        send.putExtra(Intent.EXTRA_TEXT, text);
        super.startActivity(Intent.createChooser(send, null));
        Log.i(getPackageName(), "showed the share sheet");
    }

    private void setEnvironmentFromIntent(String tag) {
        Bundle extras = getIntent().getExtras();
        if (extras == null || (getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            return;
        }
        for (String key : extras.keySet()) {
            Object value = extras.get(key);
            if (!key.startsWith(ENV_PREFIX) || !(value instanceof String)) {
                continue;
            }
            String variable = key.substring(ENV_PREFIX.length());
            try {
                Os.setenv(variable, (String) value, true);
                Log.i(tag, "environment " + variable + "=" + value);
            } catch (ErrnoException e) {
                Log.e(tag, "could not set " + variable, e);
            }
        }
    }

    // SPDX-SnippetBegin
    // SPDX-SnippetCopyrightText: 2006-2024 LOVE Development Team
    // SPDX-License-Identifier: Zlib
    // love-android's GameActivity (app/src/main/java/org/love2d/android/GameActivity.java at 1c89bb0b2e,
    // lines 203-303), the methods src/common/android.cpp calls, without androidx: vibrate,
    // hasBackgroundMusic, getDPIScale, getSafeArea, setImmersiveMode, getImmersiveMode, and
    // hasRecordAudioPermission. vibrate hands the buzz to the buzzer's thread.
    public void vibrate(double seconds) {
        if (vibrator != null) {
            long duration = (long) (seconds * 1000.);
            buzzer.execute(() -> vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)));
        }
    }

    public boolean hasBackgroundMusic() {
        AudioManager audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
        return audioManager.isMusicActive();
    }

    public float getDPIScale() {
        DisplayMetrics metrics = getResources().getDisplayMetrics();
        return metrics.density;
    }

    public Rect getSafeArea() {
        Rect rect = null;

        if (Build.VERSION.SDK_INT >= 28) {
            DisplayCutout cutout = getWindow().getDecorView().getRootWindowInsets().getDisplayCutout();

            if (cutout != null) {
                rect = new Rect();
                rect.set(
                    cutout.getSafeInsetLeft(),
                    cutout.getSafeInsetTop(),
                    cutout.getSafeInsetRight(),
                    cutout.getSafeInsetBottom()
                );
            }
        }

        return rect;
    }

    public void setImmersiveMode(boolean enable) {
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams attr = getWindow().getAttributes();

            if (enable) {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            } else {
                attr.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;
            }
        }

        shortEdgesMode = enable;
    }

    public boolean getImmersiveMode() {
        return shortEdgesMode;
    }

    public boolean hasRecordAudioPermission() {
        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }
    // SPDX-SnippetEnd
}
