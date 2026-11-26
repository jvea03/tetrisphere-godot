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

// ---------------------------------------------------------------- Meta SDK
// FBSDKApplicationDelegate / FBSDKSettings / FBSDKAppEvents are found by name
// (module FBSDKCoreKit, package FacebookCore 17.4.0) and every selector is checked
// with respondsToSelector: first, so a missing class or a renamed method means
// "Meta does nothing", never a crash. Info.plist (written by the EggAnalytics
// export plugin) starts auto-logging and advertiser-ID collection OFF.

static id meta_shared(Class cls, SEL a, SEL b) {
	if (cls == nil) {
		return nil;
	}
	if ([cls respondsToSelector:a]) {
		return ((id(*)(id, SEL))objc_msgSend)(cls, a);
	}
	if ([cls respondsToSelector:b]) {
		return ((id(*)(id, SEL))objc_msgSend)(cls, b);
	}
	return nil;
}

static void meta_set_bool(id target, SEL setter, bool value) {
	if (target != nil && [target respondsToSelector:setter]) {
		((void (*)(id, SEL, BOOL))objc_msgSend)(target, setter, value ? YES : NO);
	}
}

// The player's answer to the iOS tracking prompt (3 = authorized).
bool EggAnalytics::attAuthorized() {
	Class att = NSClassFromString(@"ATTrackingManager");
	if (att == nil || ![att respondsToSelector:@selector(trackingAuthorizationStatus)]) {
		return false;
	}
	NSUInteger status = ((NSUInteger(*)(id, SEL))objc_msgSend)(att, @selector(trackingAuthorizationStatus));
	return status == 3;
}

void EggAnalytics::setMeta(bool on) {
	Class delegate_class = NSClassFromString(@"FBSDKApplicationDelegate");
	Class settings_class = NSClassFromString(@"FBSDKSettings");
	if (delegate_class == nil || settings_class == nil) {
		if (on) {
			print_line("[EggAnalytics] Meta SDK is not linked into this build");
		}
		return;
	}
	id settings = meta_shared(settings_class, @selector(sharedSettings), @selector(shared));
	if (!on) {
		// It cannot be un-started, but it stops logging and reading the ID.
		meta_set_bool(settings, @selector(setIsAutoLogAppEventsEnabled:), false);
		meta_set_bool(settings, @selector(setAutoLogAppEventsEnabled:), false);
		meta_set_bool(settings, @selector(setIsAdvertiserIDCollectionEnabled:), false);
		meta_set_bool(settings, @selector(setAdvertiserIDCollectionEnabled:), false);
		return;
	}
	bool att = attAuthorized();
	meta_set_bool(settings, @selector(setIsAutoLogAppEventsEnabled:), true);
	meta_set_bool(settings, @selector(setAutoLogAppEventsEnabled:), true);
	// The advertising ID only with a yes on the tracking prompt.
	meta_set_bool(settings, @selector(setIsAdvertiserIDCollectionEnabled:), att);
	meta_set_bool(settings, @selector(setAdvertiserIDCollectionEnabled:), att);
	// FBSDK 17+ reads ATTrackingManager itself on iOS 17+; this flag is for older iOS.
	meta_set_bool(settings, @selector(setIsAdvertiserTrackingEnabled:), att);
	if (meta_started) {
		return;
	}
	id app_delegate = meta_shared(delegate_class, @selector(sharedInstance), @selector(shared));
	if (app_delegate != nil && [app_delegate respondsToSelector:@selector(initializeSDK)]) {
		((void (*)(id, SEL))objc_msgSend)(app_delegate, @selector(initializeSDK));
		meta_started = true;
	} else {
		print_line("[EggAnalytics] Meta SDK has no initializeSDK; left off");
		return;
	}
	// The SDK normally logs App Install / App Launch when the app becomes active,
	// which has already happened by the time consent arrives: log it now.
	Class events_class = NSClassFromString(@"FBSDKAppEvents");
	id events = meta_shared(events_class, @selector(sharedInstance), @selector(shared));
	if (events != nil && [events respondsToSelector:@selector(activateApp)]) {
		((void (*)(id, SEL))objc_msgSend)(events, @selector(activateApp));
	}
}

void EggAnalytics::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start", "api_key", "app_id", "project_id", "sender_id"), &EggAnalytics::start);
	ClassDB::bind_method(D_METHOD("logEvent", "name", "params"), &EggAnalytics::logEvent);
	ClassDB::bind_method(D_METHOD("setUserProperty", "name", "value"), &EggAnalytics::setUserProperty);
	ClassDB::bind_method(D_METHOD("setMeta", "on"), &EggAnalytics::setMeta);
	ClassDB::bind_method(D_METHOD("attAuthorized"), &EggAnalytics::attAuthorized);
}

EggAnalytics::EggAnalytics() {}

EggAnalytics::~EggAnalytics() {}
