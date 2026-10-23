package com.jvea.eggnotify;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Local notifications for Egg Escape. The game schedules a few reminders as it
 * goes to the background (a chest or build finishing, the Daily Egg) and
 * cancels them all when it comes back. Each one is an inexact alarm, which
 * needs no special permission, delivered to NotifyReceiver.
 */
public class EggNotify extends GodotPlugin {
    static final String CHANNEL = "reminders";
    private static final String PREFS = "egg_notify";
    private static final String IDS = "ids";

    public EggNotify(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "EggNotify";
    }

    static void ensureChannel(Context ctx) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = ctx.getSystemService(NotificationManager.class);
            if (nm != null && nm.getNotificationChannel(CHANNEL) == null) {
                NotificationChannel ch = new NotificationChannel(CHANNEL, "Reminders", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("Chests, builds and the Daily Egg");
                nm.createNotificationChannel(ch);
            }
        }
    }

    private Context ctx() {
        Activity a = getActivity();
        return a != null ? a.getApplicationContext() : null;
    }

    /** True once the game may post notifications (always, below Android 13). */
    @UsedByGodot
    public boolean hasPermission() {
        Context c = ctx();
        if (c == null) return false;
        if (Build.VERSION.SDK_INT < 33) return true;
        return c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }

    /** Android 13+'s system prompt; nothing happens where it is not needed. */
    @UsedByGodot
    public void requestPermission() {
        Activity a = getActivity();
        if (a == null || Build.VERSION.SDK_INT < 33 || hasPermission()) return;
        a.runOnUiThread(() -> a.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 7301));
    }

    private PendingIntent pending(Context c, int id, String title, String body) {
        Intent i = new Intent(c, NotifyReceiver.class);
        i.putExtra("id", id);
        i.putExtra("title", title);
        i.putExtra("body", body);
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** Shows title / body in `seconds`, replacing any earlier one with this id. */
    @UsedByGodot
    public void schedule(int id, String title, String body, int seconds) {
        Context c = ctx();
        if (c == null || seconds <= 0) return;
        ensureChannel(c);
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        long at = System.currentTimeMillis() + seconds * 1000L;
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(c, id, title, body));
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Set<String> ids = new HashSet<>(p.getStringSet(IDS, new HashSet<>()));
        ids.add(String.valueOf(id));
        p.edit().putStringSet(IDS, ids).apply();
    }

    /** Cancels every reminder still to come and clears any already showing. */
    @UsedByGodot
    public void cancelAll() {
        Context c = ctx();
        if (c == null) return;
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        for (String s : p.getStringSet(IDS, new HashSet<>())) {
            if (am != null) am.cancel(pending(c, Integer.parseInt(s), "", ""));
        }
        p.edit().remove(IDS).apply();
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.cancelAll();
    }
}
