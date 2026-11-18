#include "egganalytics.h"

#include "core/string/print_string.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

// Firebase's classes are looked up by name (FIRApp, FIROptions, FIRAnalytics) and
// sent typed objc_msgSend calls: no Firebase headers, and if the package is
// missing from a build, start() says so and every call is a no-op.

static NSString *to_ns(const String &s) {
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

void EggAnalytics::start(String api_key, String app_id, String project_id, String sender_id) {
	if (started) {
		return;
	}
	Class app_class = NSClassFromString(@"FIRApp");
	Class options_class = NSClassFromString(@"FIROptions");
	if (app_class == nil || options_class == nil || NSClassFromString(@"FIRAnalytics") == nil) {
		print_line("[EggAnalytics] Firebase is not linked into this build");
		return;
	}
	id existing = ((id(*)(id, SEL))objc_msgSend)(app_class, @selector(defaultApp));
	if (existing == nil) {
		id options = ((id(*)(id, SEL))objc_msgSend)(options_class, @selector(alloc));
		options = ((id(*)(id, SEL, id, id))objc_msgSend)(options, @selector(initWithGoogleAppID:GCMSenderID:), to_ns(app_id), to_ns(sender_id));
		if (options == nil) {
			print_line("[EggAnalytics] FIROptions refused the app id");
			return;
		}
		[options setValue:to_ns(api_key) forKey:@"APIKey"];
		[options setValue:to_ns(project_id) forKey:@"projectID"];
		((void (*)(id, SEL, id))objc_msgSend)(app_class, @selector(configureWithOptions:), options);
	}
	started = true;
}

void EggAnalytics::logEvent(String name, Dictionary params) {
	if (!started) {
		return;
	}
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	Array keys = params.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant v = params[keys[i]];
		NSString *key = to_ns(String(keys[i]));
		switch (v.get_type()) {
			case Variant::BOOL:
				dict[key] = [NSNumber numberWithLongLong:(bool)v ? 1 : 0];
				break;
			case Variant::INT:
				dict[key] = [NSNumber numberWithLongLong:(int64_t)v];
				break;
			case Variant::FLOAT:
				dict[key] = [NSNumber numberWithDouble:(double)v];
				break;
			default:
				dict[key] = to_ns(String(v));
				break;
		}
	}
	((void (*)(id, SEL, id, id))objc_msgSend)(NSClassFromString(@"FIRAnalytics"), @selector(logEventWithName:parameters:), to_ns(name), dict);
}

void EggAnalytics::setUserProperty(String name, String value) {
	if (!started) {
		return;
	}
	((void (*)(id, SEL, id, id))objc_msgSend)(NSClassFromString(@"FIRAnalytics"), @selector(setUserPropertyString:forName:), to_ns(value), to_ns(name));
}

void EggAnalytics::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start", "api_key", "app_id", "project_id", "sender_id"), &EggAnalytics::start);
	ClassDB::bind_method(D_METHOD("logEvent", "name", "params"), &EggAnalytics::logEvent);
	ClassDB::bind_method(D_METHOD("setUserProperty", "name", "value"), &EggAnalytics::setUserProperty);
}

EggAnalytics::EggAnalytics() {}

EggAnalytics::~EggAnalytics() {}
