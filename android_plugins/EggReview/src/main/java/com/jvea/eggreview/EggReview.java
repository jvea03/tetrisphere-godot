package com.jvea.eggreview;

import android.app.Activity;

import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Google Play's in-app review: the star sheet slides up over the game, so a
 * player rates without leaving it. Play decides whether it actually shows
 * (it has its own quota), and never says whether they rated, so the game
 * just asks at a happy moment, a few times, well apart.
 */
public class EggReview extends GodotPlugin {
    public EggReview(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "EggReview";
    }

    @UsedByGodot
    public void requestReview() {
        Activity a = getActivity();
        if (a == null) return;
        a.runOnUiThread(() -> {
            ReviewManager m = ReviewManagerFactory.create(a);
            m.requestReviewFlow().addOnCompleteListener(task -> {
                if (task.isSuccessful()) m.launchReviewFlow(a, task.getResult());
            });
        });
    }
}
