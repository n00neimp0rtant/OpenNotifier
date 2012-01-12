#import <Preferences/Preferences.h>

@interface OpenNotifierSettingsListController: PSListController {
}
@end

@implementation OpenNotifierSettingsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"OpenNotifierSettings" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
