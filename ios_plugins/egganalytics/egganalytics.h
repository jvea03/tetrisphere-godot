#ifndef EGGANALYTICS_H
#define EGGANALYTICS_H

// Firebase Analytics on iOS, as the same "EggAnalytics" singleton the Android
// plugin gives scripts/meta/analytics.gd: start(), logEvent(), setUserProperty().
// Firebase itself comes in as a Swift package (addons/EggAnalytics/export_plugin.gd)
// and is called through the Objective-C runtime, so this builds against Godot's
// headers alone.

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/dictionary.h"

class EggAnalytics : public Object {
	GDCLASS(EggAnalytics, Object);

	bool started = false;

protected:
	static void _bind_methods();

public:
	void start(String api_key, String app_id, String project_id, String sender_id);
	void logEvent(String name, Dictionary params);
	void setUserProperty(String name, String value);

	EggAnalytics();
	~EggAnalytics();
};

#endif
