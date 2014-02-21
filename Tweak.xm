#import "Tweak.h"
#import "Preferences.h"
#import <LibStatusBar/LSStatusBarItem.h>
#import <notify.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard7/SBMediaController.h>
#import <SpringBoard7/SBUserAgent.h>
#import <SpringBoard7/SBSoundPreferences.h>

#pragma mark #region [ Private Variables ]
static ONPreferences* preferences;
static NSMutableDictionary* statusBarItems = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* currentIconSetList = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* trackedBadges = [[NSMutableDictionary alloc] init];
static LSStatusBarItem* silentIconItem;
static LSStatusBarItem* vibrateIconItem;
#pragma mark #endregion

#pragma mark #region [ Global Functions ]

static LSStatusBarItem* CreateStatusBarItem(NSString* uniqueName, NSString* iconName, bool onLeft)
{
	LSStatusBarItem* item = [[[%c(LSStatusBarItem) alloc] 
		initWithIdentifier:[NSString stringWithFormat:@"opennotifier.%@", uniqueName] 
		alignment:onLeft ? StatusBarAlignmentLeft : StatusBarAlignmentRight] autorelease];
				
	item.imageName = [NSString stringWithFormat:@"ON_%@", iconName];		
	return item;
}

static void ProcessApplicationIcon(NSString* identifier)
{
	if (!preferences.enabled) return;	
	
	ONApplication* app;
	if (!(app = [preferences getApplication:identifier])) return;
	bool shouldShow = [[trackedBadges objectForKey:identifier] boolValue];
	
	for (NSString* name in app.icons.allKeys)
	{
		if (![currentIconSetList.allKeys containsObject:name]) continue; // icon doesn't exist
		
		ONApplicationIcon* icon = [app.icons objectForKey:name];			
		bool onLeft;								
		switch (icon.alignment)
		{
			case ONIconAlignmentLeft: onLeft = true; break;
			case ONIconAlignmentRight: onLeft = false; break;
			default: onLeft = preferences.iconsOnLeft; break;
		}
				
		// avoid colliding with another icon with the same name	and alignment
		NSString* uniqueName = [NSString stringWithFormat:@"%@~%d", name, onLeft];

		// applications may be sharing name and alignment so lets 
		// track it properly before we readd or remove it		
		NSMutableDictionary* uniqueIcon = [statusBarItems objectForKey:uniqueName];
		if (!uniqueIcon) uniqueIcon = [NSMutableDictionary dictionary];
		
		NSMutableArray* apps = [uniqueIcon objectForKey:ONApplicationsKey];
		if (!apps) apps = [NSMutableArray array];
		
		if (!shouldShow)
		{
			[apps removeObject:identifier];
			if (apps.count == 0) [statusBarItems removeObjectForKey:uniqueName];
		}
		else
		{	
			[apps addObject:identifier];
			[uniqueIcon setObject:apps forKey:ONApplicationsKey];
			
			if (![uniqueIcon.allKeys containsObject:ONIconNameKey])
				[uniqueIcon setObject:CreateStatusBarItem(uniqueName, name, onLeft) forKey:ONIconNameKey];
			
			[statusBarItems setObject:uniqueIcon forKey:uniqueName];			
		}
	}	
}

static void ReloadSettings()
{
	if (!preferences) preferences = ONPreferences.sharedInstance;
	else [preferences reload];
}

static void UpdateSilentIcon()
{
	if (silentIconItem) 
	{ 
		[silentIconItem release];
		silentIconItem = nil;
	}
		
	if (preferences.silentModeEnabled)
	{
		bool muted = false;
		if (%c(SBMediaController) && [%c(SBMediaController) instancesRespondToSelector:@selector(isRingerMuted)]) 
		{
			muted = [[%c(SBMediaController) sharedInstance] isRingerMuted];
		}
		else 
		{
			// I'm not sure if this is needed or not but leaving it here just in case
			// it needs to be backwards compatible
			uint64_t state; 
			int token; 
			notify_register_check("com.apple.springboard.ringerstate", &token); 
			notify_get_state(token, &state); 
			notify_cancel(token); 	
			muted = (!state);
		}
	
		if (muted) silentIconItem = [CreateStatusBarItem(ONSilentKey, ONSilentKey, preferences.silentIconOnLeft) retain];
	}
}

static void SilentModeSettingsChanged()
{
	ReloadSettings();	
	UpdateSilentIcon();
}

static void UpdateVibrateIcon()
{
	if (vibrateIconItem)
	{
		[vibrateIconItem release];
		vibrateIconItem = nil;
	}

	if (preferences.vibrateModeEnabled)
	{
        bool vibrate = false;
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
        if (dict) {
            vibrate = ([[dict valueForKey:@"ring-vibrate"] boolValue] || [[dict valueForKey:@"silent-vibrate"] boolValue]);
        }

		if (vibrate) vibrateIconItem = [CreateStatusBarItem(ONVibrateKey, ONVibrateKey, preferences.vibrateIconOnLeft) retain];
	}
}

static void VibrateModeSettingsChanged()
{
	ReloadSettings();
	UpdateVibrateIcon();
}

static void IconSettingsChanged()
{
	ReloadSettings();
	
	[statusBarItems removeAllObjects];

	if (!preferences.enabled) return;
	
	[trackedBadges.allKeys enumerateObjectsUsingBlock: ^(id key, NSUInteger index, BOOL* stop){
		ProcessApplicationIcon(key);
	}];		
}
#pragma mark #endregion

#pragma mark #region [ SpringBoard ]
%hook SpringBoard

-(id)init
{	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	ReloadSettings();	
	NSMutableArray* imageNames = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager] 
		contentsOfDirectoryAtPath:@"/System/Library/Frameworks/UIKit.framework/" error:nil]
	];

	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:IconRegexPattern
		options:NSRegularExpressionCaseInsensitive error:nil];
	
	for (NSString* name in imageNames)
	{		
		NSTextCheckingResult* match = [regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
		if (!match) continue;
		name = [name substringWithRange:[match rangeAtIndex:1]];
		[currentIconSetList setObject:[NSMutableSet setWithCapacity:1] forKey:name];
	}
	
	[pool drain];
	return %orig;
}

-(void)applicationDidFinishLaunching:(id)application
{
	%orig;
	UpdateSilentIcon();	
	UpdateVibrateIcon();
	
	AddObserver((CFStringRef)IconSettingsChangedNotification, IconSettingsChanged);
	AddObserver((CFStringRef)SilentModeChangedNotification, SilentModeSettingsChanged);
	AddObserver((CFStringRef)VibrateModeChangedNotification, VibrateModeSettingsChanged);

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.ring-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.silent-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
									
	#ifdef DEBUGPREFS
	dispatch_queue_t queue = dispatch_get_main_queue();
	dispatch_async(queue, 
	^{
		SBAwayController* c = [%c(SBAwayController) sharedAwayController];
		[c attemptUnlock];
		[c unlockWithSound:false];
		[[%c(SBUserAgent) sharedUserAgent] openURL:[NSURL URLWithString:@"prefs:root=OpenNotifier"] allowUnlock:true animated:true];
		dispatch_release(queue);	
	});
	#endif
}
%end
#pragma mark #endregion

#pragma mark #region [ SBMediaController ]
%hook SBMediaController
-(void)setRingerMuted:(bool)change
{
	%orig;
	UpdateSilentIcon();
}
%end
#pragma mark #endregion

#pragma mark #region [ SBSoundPreferences ]
%hook SBSoundPreferences
-(void)userDefaultsDidChanged:(id)arg1
{
	%orig;
	UpdateVibrateIcon();
}
%end
#pragma mark #endregion

#pragma mark #region [ SBApplication ]
%hook SBApplication

-(void)setBadge:(id)badge
{
	%orig;

//	NSLog(@"SBApplication setBadge - identifier = %@ - %@, badge = %@", self.bundleIdentifier, self.displayIdentifier, badge);
	
	bool showBadge = !(badge == NULL || badge == nil || [badge isEqual:@""] || [badge isEqual:@"0"] || [badge isEqual:[NSNumber numberWithInt:0]]);
	[trackedBadges setObject:NSBool(showBadge) forKey:self.bundleIdentifier];
	if (preferences.enabled) ProcessApplicationIcon(self.bundleIdentifier);
}
%end
#pragma mark #endregion
