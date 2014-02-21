

NSString* const ONAppIdentifierKey = @"ONAppIdentifier";
NSString* const ONApplicationsKey = @"apps";
NSString* const ONEnabledKey = @"ONEnabled";
NSString* const ONIconsKey = @"icons";
NSString* const ONIconAlignmentKey = @"IconAlignment";
NSString* const ONIconNameKey = @"IconName";
NSString* const ONIconsLeftKey = @"ONNotifIconsLeft";
NSString* const ONPreferencesFile = @"/var/mobile/Library/Preferences/com.n00neimp0rtant.opennotifier.plist";
NSString* const ONSchemaVersionKey = @"SchemaVersion";
NSString* const ONSilentKey = @"Silent";
NSString* const ONSilentIconLeftKey = @"ONSilentIconLeft";
NSString* const ONSilentModeEnabledKey = @"ONSilentModeIcon";
NSString* const ONVibrateKey = @"Vibrate";
NSString* const ONVibrateIconLeftKey = @"ONVibrateIconLeft";
NSString* const ONVibrateModeEnabledKey = @"ONVibrateModeIcon";

NSString* const IconRegexPattern = @"(?:Silver|Black)_ON_(.*?)(?:@.*|)(?:~.*|).png";
NSString* const SilverIconRegexPattern = @"Silver_ON_(.*?)(?:@.*|)(?:~.*|).png";

NSString* const IconSettingsChangedNotification = @"opennotifier.iconSettingsChanged";
NSString* const SilentModeChangedNotification = @"opennotifier.silentModeChanged";
NSString* const VibrateModeChangedNotification = @"opennotifier.vibrateModeChanged";
