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
}
