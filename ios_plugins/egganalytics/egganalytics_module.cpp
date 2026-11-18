#include "egganalytics_module.h"

#include "core/config/engine.h"

#include "egganalytics.h"

static EggAnalytics *egg_analytics = nullptr;

void register_egganalytics_types() {
	GDREGISTER_CLASS(EggAnalytics);
	egg_analytics = memnew(EggAnalytics);
	Engine::get_singleton()->add_singleton(Engine::Singleton("EggAnalytics", egg_analytics));
}

void unregister_egganalytics_types() {
	if (egg_analytics) {
		memdelete(egg_analytics);
		egg_analytics = nullptr;
	}
}
