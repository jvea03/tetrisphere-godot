package com.jvea.egganalytics;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.Choreographer;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.analytics.FirebaseAnalytics;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Firebase Analytics: first opens and a few game events (scripts/meta/analytics.gd),
 * which Google Ads imports as conversions, so the install campaign can aim at
 * players who actually play. There is no google-services.json (the Gradle
 * build template stays as Godot installs it): the project's IDs are string
 * resources (res/values/firebase.xml), which Analytics itself needs, and
 * start() initializes Firebase with them if it isn't already.
 */
public class EggAnalytics extends GodotPlugin {
    private static final String TAG = "EggAnalytics";
    private FirebaseAnalytics analytics;
    private Context appContext;

    public EggAnalytics(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "EggAnalytics";
    }

    @UsedByGodot
    public void start(String apiKey, String appId, String projectId, String senderId) {
        Activity a = getActivity();
        if (a == null || analytics != null) return;
        Context c = a.getApplicationContext();
        if (FirebaseApp.getApps(c).isEmpty()) {
            FirebaseOptions o = new FirebaseOptions.Builder()
                    .setApiKey(apiKey)
                    .setApplicationId(appId)
                    .setProjectId(projectId)
                    .setGcmSenderId(senderId)
                    .build();
            FirebaseApp.initializeApp(c, o);
        }
        analytics = FirebaseAnalytics.getInstance(c);
        appContext = c;
    }

    @UsedByGodot
    public void logEvent(String name, Dictionary params) {
        if (analytics == null) return;
        Bundle b = new Bundle();
        for (Map.Entry<String, Object> e : params.entrySet()) {
            Object v = e.getValue();
            if (v instanceof Integer || v instanceof Long) b.putLong(e.getKey(), ((Number) v).longValue());
            else if (v instanceof Number) b.putDouble(e.getKey(), ((Number) v).doubleValue());
            else if (v instanceof Boolean) b.putLong(e.getKey(), ((Boolean) v) ? 1 : 0);
            else b.putString(e.getKey(), String.valueOf(v));
        }
        analytics.logEvent(name, b);
    }

    /**
     * The Meta (Facebook) SDK, for Meta app-install ads. The manifest does not
     * start it (AutoInitEnabled, AutoLogAppEvents and advertiser-id collection
     * are false, and FacebookInitProvider is removed: addons/EggMeta). Only
     * this method does, and only while the player's analytics are allowed
     * (consent in the UK/EEA/Switzerland, the Settings switch everywhere:
     * scripts/meta/analytics.gd sync_meta).
     *
     * Returns immediately. On true, initialization runs after the next frame
     * and off the main thread (sdkInitialize reads files and loads gatekeepers;
     * doing that on the main thread at process start is the startup ANR).
     * Once it finishes, the install and the app activation are still logged.
     * On false it stops logging and stops reading the advertising ID (the SDK
     * can't be un-started, but nothing more is sent). Builds without the Meta
     * SDK (no IDs set) do nothing.
     */
    @UsedByGodot
    public void setMeta(boolean on) {
        try {
            Meta.set(this, context(), on);
        } catch (Throwable t) {
            // no Meta SDK in this build
        }
    }

    /**
     * One Meta standard event (AppEventsLogger.logEvent). No-op unless
     * setMeta(true) has been called, which is only while analytics are allowed.
     * If the deferred init has not finished yet, the event is held and written
     * once it has, so a call in the same turn as setMeta (level 10, the first
     * lesson) is not dropped. name and param keys are the AppEventsConstants
     * strings (fb_mobile_level_achieved / fb_level, fb_mobile_tutorial_completion).
     * Builds without the Meta SDK do nothing.
     */
    @UsedByGodot
    public void logMetaEvent(String name, Dictionary params) {
        try {
            Meta.log(context(), name, params);
        } catch (Throwable t) {
            // no Meta SDK in this build
        }
    }

    private Context context() {
        if (appContext != null) return appContext;
        Activity a = getActivity();
        if (a == null) return null;
        appContext = a.getApplicationContext();
        return appContext;
    }

    /**
     * Own class, so a build without the Meta SDK never loads the Facebook
     * classes until setMeta / logMetaEvent actually runs.
     */
    private static final class Meta {
        static final Handler MAIN = new Handler(Looper.getMainLooper());
        static final ExecutorService BG = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "egg-meta");
            t.setDaemon(true);
            return t;
        });

        /** Consent. Set on the caller thread; the SDK work follows later. */
        static volatile boolean enabled = false;
        /** sdkInitialize has finished and install/activate have been requested. */
        static volatile boolean ready = false;
        static volatile boolean debug = false;
        static final AtomicBoolean scheduled = new AtomicBoolean(false);
        static final AtomicBoolean started = new AtomicBoolean(false);
        static final List<Pending> pending = new ArrayList<>();
        static WeakReference<EggAnalytics> pluginRef = new WeakReference<>(null);

        static void set(EggAnalytics plugin, Context context, boolean on) {
            pluginRef = new WeakReference<>(plugin);
            enabled = on;
            if (!on) {
                synchronized (pending) {
                    pending.clear();
                }
                if (started.get()) {
                    BG.execute(Meta::disable);
                }
                return;
            }
            Context app = context != null ? context.getApplicationContext() : null;
            if (ready) {
                if (app != null) BG.execute(() -> enableLogging(app));
                return;
            }
            if (scheduled.compareAndSet(false, true)) {
                Log.i(TAG, "Meta SDK init deferred until after the next frame");
                afterFrame(plugin, 0);
            }
        }

        /** Snapshot on the caller thread. Facebook classes are not touched. */
        static void log(Context context, String name, Dictionary params) {
            if (!enabled || context == null || name == null || name.isEmpty()) return;
            Pending event = new Pending(context.getApplicationContext(), name, copy(params));
            synchronized (pending) {
                if (!ready) {
                    pending.add(event);
                    return;
                }
            }
            BG.execute(() -> write(event));
        }

        static Map<String, Object> copy(Dictionary params) {
            Map<String, Object> out = new HashMap<>();
            if (params == null) return out;
            for (Map.Entry<String, Object> e : params.entrySet()) {
                if (e.getKey() != null && e.getValue() != null) out.put(e.getKey(), e.getValue());
            }
            return out;
        }

        /** One frame later, so the first presented frame is not waiting on the SDK. */
        static void afterFrame(EggAnalytics plugin, int attempt) {
            MAIN.post(() -> {
                if (!enabled) {
                    scheduled.set(false);
                    return;
                }
                Runnable go = () -> {
                    if (!enabled) {
                        scheduled.set(false);
                        return;
                    }
                    Context ctx = plugin.context();
                    if (ctx == null) {
                        if (attempt < 120) afterFrame(plugin, attempt + 1);
                        else {
                            scheduled.set(false);
                            Log.w(TAG, "Meta SDK init skipped: no activity");
                        }
                        return;
                    }
                    BG.execute(() -> init(plugin, ctx));
                };
                try {
                    Choreographer.getInstance().postFrameCallback(frameTimeNanos -> go.run());
                } catch (Throwable t) {
                    go.run();
                }
            });
        }

        @SuppressWarnings("deprecation")
        static void init(EggAnalytics plugin, Context app) {
            if (!enabled) {
                // Consent was revoked before this ran. Allow a later setMeta(true).
                scheduled.set(false);
                return;
            }
            if (!started.compareAndSet(false, true)) return;
            long t0 = SystemClock.elapsedRealtime();
            try {
                // The provider used to call this on the main thread at process
                // start. It is deprecated because of that provider; with the
                // provider removed, this is the init.
                if (!com.facebook.FacebookSdk.isInitialized()) {
                    com.facebook.FacebookSdk.sdkInitialize(app);
                }
                if (!enabled) {
                    disable();
                    started.set(false);
                    scheduled.set(false);
                    return;
                }
                if ((app.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
                    debug = true;
                    // Events Manager > Test Events reads these. Release builds leave them off.
                    com.facebook.FacebookSdk.setIsDebugEnabled(true);
                    com.facebook.FacebookSdk.addLoggingBehavior(com.facebook.LoggingBehavior.APP_EVENTS);
                }
                com.facebook.FacebookSdk.setAdvertiserIDCollectionEnabled(true);
                com.facebook.FacebookSdk.setAutoInitEnabled(true);
                com.facebook.FacebookSdk.fullyInitialize();
                com.facebook.FacebookSdk.setAutoLogAppEventsEnabled(true);
                if (app instanceof Application) {
                    // Install (once per install). Lifecycle callbacks alone miss
                    // it, because the activity has already resumed by now.
                    com.facebook.appevents.AppEventsLogger.activateApp((Application) app);
                }
                MAIN.post(() -> {
                    try {
                        if (enabled) activateCurrent(plugin);
                    } catch (Throwable t) {
                        Log.w(TAG, "Meta activate failed", t);
                    }
                    BG.execute(() -> {
                        if (!enabled) {
                            synchronized (pending) {
                                pending.clear();
                            }
                            disable();
                            ready = false;
                            started.set(false);
                            scheduled.set(false);
                            return;
                        }
                        flush();
                        Log.i(TAG, "Meta SDK ready in " + (SystemClock.elapsedRealtime() - t0)
                                + " ms on " + Thread.currentThread().getName()
                                + " (install and activate requested)");
                    });
                });
            } catch (Throwable t) {
                started.set(false);
                scheduled.set(false);
                Log.w(TAG, "Meta SDK init failed", t);
            }
        }

        /** fb_mobile_activate_app for the activity that is already resumed. Main thread. */
        static void activateCurrent(EggAnalytics plugin) {
            Activity activity = plugin.getActivity();
            if (activity == null || activity.isFinishing() || activity.isDestroyed()) return;
            com.facebook.appevents.internal.ActivityLifecycleTracker.onActivityResumed(activity);
        }

        static void enableLogging(Context app) {
            try {
                com.facebook.FacebookSdk.setAdvertiserIDCollectionEnabled(true);
                com.facebook.FacebookSdk.setAutoInitEnabled(true);
                com.facebook.FacebookSdk.fullyInitialize();
                com.facebook.FacebookSdk.setAutoLogAppEventsEnabled(true);
                if (app instanceof Application) {
                    com.facebook.appevents.AppEventsLogger.activateApp((Application) app);
                }
                EggAnalytics plugin = pluginRef.get();
                if (plugin != null) {
                    MAIN.post(() -> {
                        try {
                            if (enabled) activateCurrent(plugin);
                        } catch (Throwable t) {
                            Log.w(TAG, "Meta activate failed", t);
                        }
                    });
                }
            } catch (Throwable t) {
                Log.w(TAG, "Meta re-enable failed", t);
            }
        }

        static void disable() {
            try {
                if (!com.facebook.FacebookSdk.isInitialized()) return;
                com.facebook.FacebookSdk.setAutoLogAppEventsEnabled(false);
                com.facebook.FacebookSdk.setAdvertiserIDCollectionEnabled(false);
                com.facebook.FacebookSdk.setAutoInitEnabled(false);
            } catch (Throwable t) {
                Log.w(TAG, "Meta disable failed", t);
            }
        }

        static void flush() {
            List<Pending> batch;
            synchronized (pending) {
                ready = true;
                batch = new ArrayList<>(pending);
                pending.clear();
            }
            for (Pending event : batch) write(event);
        }

        static void write(Pending event) {
            if (!enabled || event.context == null) return;
            Bundle b = new Bundle();
            for (Map.Entry<String, Object> e : event.params.entrySet()) {
                String key = e.getKey();
                Object v = e.getValue();
                if (key == null || v == null) continue;
                // fb_level is AppEventsConstants.EVENT_PARAM_LEVEL, and Meta wants it as text.
                if (com.facebook.appevents.AppEventsConstants.EVENT_PARAM_LEVEL.equals(key)) {
                    b.putString(com.facebook.appevents.AppEventsConstants.EVENT_PARAM_LEVEL, String.valueOf(v));
                } else if (v instanceof Integer || v instanceof Long) {
                    b.putLong(key, ((Number) v).longValue());
                } else if (v instanceof Number) {
                    b.putDouble(key, ((Number) v).doubleValue());
                } else if (v instanceof Boolean) {
                    b.putLong(key, ((Boolean) v) ? 1 : 0);
                } else {
                    b.putString(key, String.valueOf(v));
                }
            }
            String name = event.name;
            if (com.facebook.appevents.AppEventsConstants.EVENT_NAME_ACHIEVED_LEVEL.equals(name)) {
                name = com.facebook.appevents.AppEventsConstants.EVENT_NAME_ACHIEVED_LEVEL;
            } else if (com.facebook.appevents.AppEventsConstants.EVENT_NAME_COMPLETED_TUTORIAL.equals(name)) {
                name = com.facebook.appevents.AppEventsConstants.EVENT_NAME_COMPLETED_TUTORIAL;
            }
            com.facebook.appevents.AppEventsLogger logger =
                    com.facebook.appevents.AppEventsLogger.newLogger(event.context);
            logger.logEvent(name, b);
            if (debug) logger.flush();
        }

        static final class Pending {
            final Context context;
            final String name;
            final Map<String, Object> params;

            Pending(Context context, String name, Map<String, Object> params) {
                this.context = context;
                this.name = name;
                this.params = params;
            }
        }
    }

    @UsedByGodot
    public void setUserProperty(String name, String value) {
        if (analytics == null) return;
        analytics.setUserProperty(name, value);
    }
}
