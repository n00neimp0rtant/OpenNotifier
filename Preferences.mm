#import "Tweak.h"
#import "Preferences.h"

#pragma mark #region [ ONApplicationIcon ]
@implementation ONApplicationIcon
+(id)createInstance { return [[ONApplicationIcon alloc] init]; }
+(id)createInstanceWithDictionary:(NSMutableDictionary*)aDictionary { return [[ONApplicationIcon alloc] initWithDictionary:aDictionary]; }

-(id)init
{
	if (!(self = [super init])) return nil;
	_dictionary = [[NSMutableDictionary alloc] init];
	return self;
}

-(id)initWithDictionary:(NSMutableDictionary*)aDictionary
{
	if (![self init]) return nil;
	_dictionary = [aDictionary retain];
	return self;
}

-(void)dealloc
{
	[_dictionary release];
	[super dealloc];
}

-(ONIconAlignment)alignment
{
	return [_dictionary.allKeys containsObject:ONIconAlignmentKey] 
		? (ONIconAlignment)[[_dictionary objectForKey:ONIconAlignmentKey] intValue] 
		: ONIconAlignmentDefault;
}

-(void)setAlignment:(ONIconAlignment)value
{
	[_dictionary setObject:[NSNumber numberWithUnsignedInt:value] forKey:ONIconAlignmentKey];
}

-(NSMutableDictionary*)toDictionary { return _dictionary; }

@end
#pragma mark #endregion

#pragma mark #region [ ONApplication ]
@implementation ONApplication
@synthesize icons;

+(id)createInstance
{
	return [[ONApplication alloc] init];
}

-(id)init 
{
	if (!(self = [super init])) return nil;
	self.icons = [NSMutableDictionary dictionary];
	return self;
}

-(void)dealloc
{
	[self.icons release];
	[super dealloc];
}

-(NSMutableDictionary*)toDictionary
{
	NSMutableDictionary* value = [NSMutableDictionary dictionary];
	if (self.icons.allKeys.count > 0)
	{
		NSMutableDictionary* iconDict = [NSMutableDictionary dictionary];
		for (NSString* name in self.icons.allKeys)
		{
			ONApplicationIcon* icon = [self.icons objectForKey:name];
			if (icon) [iconDict setObject:[icon toDictionary] forKey:name];
		}
		[value setObject:iconDict forKey:ONIconsKey];
	}
	
	return value;
}

-(id)addIcon:(NSString*)iconName
{
	[self.icons setObject:[ONApplicationIcon createInstance] forKey:iconName];
	return [self.icons objectForKey:iconName];
}

-(void)removeIcon:(NSString*)iconName
{
	[self.icons removeObjectForKey:iconName];
}

-(bool)containsIcon:(NSString*)iconName
{
	return [self.icons.allKeys containsObject:iconName];
}

@end
#pragma mark #endregion

#pragma mark #region [ ONPreferences ]
static ONPreferences* _instance;
@implementation ONPreferences

+(id)sharedInstance
{ 		
	return (_instance = [[[ONPreferences alloc] init] retain]);
}

-(id)init
{
	if (_instance) { [self release]; return _instance; }	
	if (!(self = [super init])) return nil;
	[self reload];	
	return (_instance = self);
}

-(void)dealloc
{
	[_data release];
	[super dealloc];
}

-(int)schemaVersion
{
	return [_data.allKeys containsObject:ONSchemaVersionKey] ? [[_data objectForKey:ONSchemaVersionKey] intValue] : 0;
}

-(void)loadAppsVersion00
{
	if (![_data.allKeys containsObject:ONApplicationsKey]) return; 
	
	NSDictionary* appData = [_data objectForKey:ONApplicationsKey];
	for (NSString* identifer in appData.allKeys)
	{
		ONApplication* app = [ONApplication createInstance];
		NSArray* icons = [appData objectForKey:identifer];
		for (NSString* iconName in icons)
		{
			[app.icons setObject:[ONApplicationIcon createInstance] forKey:iconName];
		}
		
		[_applications setObject:app forKey:identifer];
	}
}

-(void)loadAppsVersion01
{
	if (![_data.allKeys containsObject:ONApplicationsKey]) return; 
	
	NSDictionary* appData = [_data objectForKey:ONApplicationsKey];
	for (NSString* identifer in appData.allKeys)
	{
		ONApplication* app = [ONApplication createInstance];
		NSMutableDictionary* icons = [[appData objectForKey:identifer] objectForKey:ONIconsKey];
		for (NSString* iconName in icons.allKeys)
		{
			[app.icons setObject:[ONApplicationIcon createInstanceWithDictionary:[icons objectForKey:iconName]] forKey:iconName];
		}
		[_applications setObject:app forKey:identifer];
	}
}

-(NSMutableDictionary*)applications
{
	if (_applications) return _applications;
	_applications = [[NSMutableDictionary alloc] init];
		
	switch (self.schemaVersion)
	{
		case 0: [self loadAppsVersion00]; break;
		default: [self loadAppsVersion01]; break;
	}
	
	return _applications;
}

-(ONApplication*)getApplication:(NSString*)identifer
{
	return [self.applications objectForKey:identifer];
}

-(void)setApplication:(ONApplication*)application named:(NSString*)identifer
{		
	[self.applications setObject:application forKey:identifer];
}

-(void)removeApplication:(NSString*)identifer
{
	[self.applications removeObjectForKey:identifer];
}

-(id)addIcon:(NSString*)iconName forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app && !(app = [ONApplication createInstance])) 
	{
		Log("Failed to get or create ONApplication");
		return nil;	
	}
	[app addIcon:iconName];
	[self setApplication:app named:identifer];
	return [app.icons objectForKey:iconName];
}

-(void)removeIcon:(NSString*)iconName fromApplication:(NSString*)identifer;
{	
	ONApplication* app = [self getApplication:identifer];
	if (!app) return;	
	[app removeIcon:iconName];
	if (app.icons.allKeys.count == 0) [self removeApplication:identifer];
}

-(ONApplicationIcon*)getIcon:(NSString*)iconName forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app) return nil;
	return [app.icons objectForKey:iconName];
}

-(bool)iconsOnLeft 
{
	return [_data.allKeys containsObject:ONIconsLeftKey] ? [[_data objectForKey:ONIconsLeftKey] boolValue] : false;
}

-(void)setIconsOnLeft:(bool)value 
{
	[_data setObject:NSBool(value) forKey:ONIconsLeftKey];
	[self save];
}

-(bool)enabled 
{
	return [_data.allKeys containsObject:ONEnabledKey] ? [[_data objectForKey:ONEnabledKey] boolValue] : true;
}

-(void)setEnabled:(bool)value 
{
	[_data setObject:NSBool(value) forKey:ONEnabledKey];
	[self save];
}

-(bool)hideMail
{
	return [_data.allKeys containsObject:ONHideMailKey] ? [[_data objectForKey:ONHideMailKey] boolValue] : false;
}

-(void)setHideMail:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONHideMailKey];
//    [self save];
	[self saveWithNotification:HideMailChangedNotification];
}

-(void)reload
{
	if (_applications) { [_applications release]; _applications = nil; }
	if (_data) [_data release];
	_data = [[NSMutableDictionary alloc] initWithContentsOfFile:ONPreferencesFile];
	if (!_data) _data = [[NSMutableDictionary alloc] init]; // new setup
}

-(void)saveWithNotification:(NSString*)notification
{
	[_data removeObjectForKey:@"pseudobadges"];	
	
	// Convert the objects back to a writeable dictionary
	// to avoid having to use NSKeyArchiver
	NSMutableDictionary* apps = [NSMutableDictionary dictionary];
	for (NSString* identifer in self.applications.allKeys)
	{
		[apps setObject:[[self getApplication:identifer] toDictionary] forKey:identifer];
	}
	[_data setObject:apps forKey:ONApplicationsKey];
		
	[_data setObject:[NSNumber numberWithUnsignedInt:ONSchemaVersion] forKey:ONSchemaVersionKey];
		
	if (![_data writeToFile:ONPreferencesFile atomically:true]) 
	{
		Log("Failed to save settings");
		return;
	}
		
	PostNotification((CFStringRef)notification);
}

-(void)save
{
	[self saveWithNotification:IconSettingsChangedNotification];
}

-(bool)silentModeEnabled
{ 
	return [_data.allKeys containsObject:ONSilentModeEnabledKey] ? [[_data objectForKey:ONSilentModeEnabledKey] boolValue] : true;
}

-(void)setSilentModeEnabled:(bool)value 
{
	[_data setObject:NSBool(value) forKey:ONSilentModeEnabledKey];
	[self saveWithNotification:SilentModeChangedNotification];
}

-(bool)silentIconOnLeft
{
	return [_data.allKeys containsObject:ONSilentIconLeftKey] ? [[_data objectForKey:ONSilentIconLeftKey] boolValue]: false;
}

-(void)setSilentIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONSilentIconLeftKey];
	[self saveWithNotification:SilentModeChangedNotification];
}

-(bool)vibrateModeEnabled
{
	return [_data.allKeys containsObject:ONVibrateModeEnabledKey] ? [[_data objectForKey:ONVibrateModeEnabledKey] boolValue] : true;
}

-(void)setVibrateModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVibrateModeEnabledKey];
	[self saveWithNotification:VibrateModeChangedNotification];
}

-(bool)vibrateIconOnLeft
{
	return [_data.allKeys containsObject:ONVibrateIconLeftKey] ? [[_data objectForKey:ONVibrateIconLeftKey] boolValue]: false;
}

-(void)setVibrateIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVibrateIconLeftKey];
	[self saveWithNotification:VibrateModeChangedNotification];
}
@end
#pragma mark #endregion