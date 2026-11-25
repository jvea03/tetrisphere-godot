package com.jvea.egganalytics;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.analytics.FirebaseAnalytics;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Map;

/**
 * Firebase Analytics: first opens and a few game events (scripts/meta/analytics.gd),
 * which Google Ads imports as conversions, so the install campaign can aim at
 * players who actually play. There is no google-services.json (the Gradle
 * build template stays as Godot installs it): the project's IDs are string
 * resources (res/values/firebase.xml), which Analytics itself needs, and
 * start() initializes Firebase with them if it isn't already.
 */
public class EggAnalytics extends GodotPlugin {
    private FirebaseAnalytics analytics;

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
     * The Meta (Facebook) SDK, for Meta app-install ads: it is not started by
     * the manifest (AutoInitEnabled false, addons/EggMeta), only here, and only
     * while the player's analytics are allowed (consent in the UK/EEA/Switzerland,
     * the Settings switch everywhere: scripts/meta/analytics.gd sync_meta). On
     * true it starts and logs app opens and installs; on false it stops logging
     * and stops reading the advertising ID (it can't be un-started, but nothing
     * more is sent). Builds without the Meta SDK (no IDs set) do nothing.
     */
    @UsedByGodot
    public void setMeta(boolean on) {
        try {
            Meta.set(on);
        } catch (Throwable t) {
            // no Meta SDK in this build
        }
    }

    /** Own class, so a build without the Meta SDK never loads it. */
    private static final class Meta {
        static void set(boolean on) {
            com.facebook.FacebookSdk.setAutoLogAppEventsEnabled(on);
            com.facebook.FacebookSdk.setAdvertiserIDCollectionEnabled(on);
            if (on) {
                com.facebook.FacebookSdk.setAutoInitEnabled(true);
                com.facebook.FacebookSdk.fullyInitialize();
            }
        }
    }

    @UsedByGodot
    public void setUserProperty(String name, String value) {
        if (analytics == null) return;
        analytics.setUserProperty(name, value);
    }
}
