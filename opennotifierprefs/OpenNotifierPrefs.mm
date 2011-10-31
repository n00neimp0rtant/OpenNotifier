#import <Preferences5/Preferences.h>

@interface OpenNotifierPrefsListController: PSListController {
}
@end

@implementation OpenNotifierPrefsListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"OpenNotifierPrefs" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
