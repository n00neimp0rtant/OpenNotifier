#import "Settings.h"
#import "Preferences.h"
#import <UIKit/UIKit.h>
#import <UIKit/UISearchBar2.h>

#pragma mark #region [ Preferences Keys ]
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_2
extern NSString* PSCellClassKey; // cellClass
extern NSString* PSIDKey; // id
extern NSString* PSIsRadioGroupKey; // isRadioGroup
extern NSString* PSRadioGroupCheckedSpecifierKey; // radioGroupCheckedSpecifier
extern NSString* PSDefaultValueKey; // default
extern NSString* PSValueKey; // value
#endif

NSString* const ONAlignmentKey = @"alignment";

#pragma mark #endregion

#pragma mark #region [ Variables & Constants ]
NSString* const iconPath = @"/System/Library/Frameworks/UIKit.framework";
static ONPreferences* preferences;
static NSMutableDictionary* cachedIcons;
static UIImage* defaultIcon;
static NSMutableArray* statusIcons;

SEL const SELGetPreferenceValue = @selector(readPreferenceValue:);
SEL const SELSetPreferenceValue = @selector(setPreferenceValue:specifier:);
#pragma mark #endregion

#pragma mark #region [ ALLinkCell ]
@interface ALLinkCell : ALValueCell
@end

@implementation ALLinkCell
-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) return nil;	
	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return self;
}
@end
#pragma mark #endregion

#pragma mark #region [ONIconCell]
@interface ONIconCell : PSTableCell
@end

@implementation ONIconCell

-(UIImage*)getIconNamed:(NSString*)name
{	
	UIImage* icon = [cachedIcons objectForKey:name];
	if (icon) return icon; // icon already cached so let's return it
	
	icon = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/Silver_ON_%@.png", iconPath, name]];	
	if (!icon) icon = defaultIcon;
		
	float maxWidth = 20.0f;
	float maxHeight = 20.0f;
	
	CGSize size = CGSizeMake(maxWidth, maxHeight);
	CGFloat scale = 1.0f;

	// the scale logic below was taken from 
	// http://developer.appcelerator.com/question/133826/detecting-new-ipad-3-dpi-and-retina
	if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)])
	{
		if ([UIScreen mainScreen].scale > 1.0f) scale = [[UIScreen mainScreen] scale];
		UIGraphicsBeginImageContextWithOptions(size, false, scale);
	}
	else UIGraphicsBeginImageContext(size);
	
	// Resize image to status bar size and center it
	// make sure the icon fits within the bounds
	CGFloat width = MIN(icon.size.width, maxWidth);
	CGFloat height = MIN(icon.size.height, maxHeight);
	
	CGFloat left = MAX((maxWidth-width)/2, 0);
	left = left > (maxWidth/2) ? maxWidth-(maxWidth/2) : left;
	
	CGFloat top = MAX((maxHeight-height)/2, 0);
	top = top > (maxHeight/2) ? maxHeight-(maxHeight/2) : top;
	
	[icon drawInRect:CGRectMake(left, top, width, height)];
	icon = [UIGraphicsGetImageFromCurrentImageContext() retain];
	UIGraphicsEndImageContext();
	
	[cachedIcons setObject:icon forKey:name];

	return icon;
}

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identifier specifier:(PSSpecifier*)specifier;
{	
	if (!(self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier])) return nil;
	NSString* name = specifier.identifier;
	[self setIcon:[self getIconNamed:name]];
	
	ONApplication* app = [preferences getApplication:[specifier propertyForKey:ONAppIdentifierKey]];
	
	bool enabled = app && [app.icons.allKeys containsObject:name];
	if (enabled) 
	{
		NSMutableString* details = [NSMutableString stringWithString:@"Enabled"];		
		ONApplicationIcon* icon = [app.icons objectForKey:name];
		if (icon)
		{
		   switch (icon.alignment)
		   {
			 case ONIconAlignmentLeft: [details appendString:@" | Force Left"]; break;
			 case ONIconAlignmentRight: [details appendString:@" | Force Right"]; break;
		   }
	   }
		
		self.detailTextLabel.text = details;
	}
	return self;
}
@end
#pragma mark #endregion

#pragma mark #region [ OpenNotifierSettingsRootController ]
@implementation OpenNotifierSettingsRootController
-(id)init
{
	if (!(self = [super init])) return nil;
	preferences = [ONPreferences.sharedInstance retain];
	return self;
}

-(void)dealloc
{
	if (cachedIcons) { [cachedIcons release]; cachedIcons = nil; }
	if (statusIcons) { [statusIcons release]; statusIcons = nil; }
	if (defaultIcon) { [defaultIcon release]; defaultIcon = nil; }
	if (preferences) { [preferences release]; preferences = nil; }
	[super dealloc];
}

-(id)specifiers 
{
	return _specifiers ? _specifiers : (_specifiers = [[self loadSpecifiersFromPlistName:@"OpenNotifierSettings" target:self] retain]);
}

-(id)readPreferenceValue:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
		
	if ([key isEqualToString:ONEnabledKey]) return NSBool(preferences.enabled);
	if ([key isEqualToString:ONIconsLeftKey]) return NSBool(preferences.iconsOnLeft);
	if ([key isEqualToString:ONSilentModeEnabledKey]) return NSBool(preferences.silentModeEnabled);
	if ([key isEqualToString:ONSilentIconLeftKey]) return NSBool(preferences.silentIconOnLeft);
	
	return nil;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	
	if ([key isEqualToString:ONEnabledKey]) preferences.enabled = [value boolValue];
	if ([key isEqualToString:ONIconsLeftKey]) preferences.iconsOnLeft = [value boolValue];
	if ([key isEqualToString:ONSilentModeEnabledKey]) preferences.silentModeEnabled = [value boolValue];
	if ([key isEqualToString:ONSilentIconLeftKey]) preferences.silentIconOnLeft = [value boolValue];
}

@end
#pragma mark #endregion

#pragma mark #region [ OpenNotifierAppsController ]
@implementation OpenNotifierAppsController

#pragma mark #region [ Controller ]
-(void)updateDataSource:(NSString*)searchText
{
	NSNumber *iconSize = [NSNumber numberWithUnsignedInteger:ALApplicationIconSizeSmall];

	NSString* filter = (searchText && searchText.length > 0) 
					 ? [NSString stringWithFormat:@"not displayName in {'Setup'} and displayName beginsWith[cd] '%@'", searchText]
					 : nil;
					 	
	if (filter)
	{
		_dataSource.sectionDescriptors = [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				NSTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				filter, ALSectionDescriptorPredicateKey
			, nil]
		, nil];
	}
	else 
	{
		_dataSource.sectionDescriptors = [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"System Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				
				@"containerPath = '/Applications' "
				"and bundleIdentifier matches 'com.apple.*' "
				"and not displayName in {'Setup'} "
				, ALSectionDescriptorPredicateKey
			, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Cydia Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				
				@"containerPath = '/Applications' "
				"and not bundleIdentifier matches 'com.apple.*' "
				, ALSectionDescriptorPredicateKey
			, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"User Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				@"containerPath != '/Applications'", ALSectionDescriptorPredicateKey
			, nil]
		, nil];		
	}	
	[_tableView reloadData];	
}

-(id)init
{		
	if (!(self = [super init])) return nil;
	
	CGRect bounds = [[UIScreen mainScreen] bounds];
	
	_dataSource = [[[ALApplicationTableDataSource alloc] init] retain];	
	_tableView = [[[UITableView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height) style:UITableViewStyleGrouped] retain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.delegate = self;	
	_tableView.dataSource = _dataSource;
	_dataSource.tableView = _tableView;
	[self updateDataSource:nil];
	
	// Search Bar	
	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	if ([_searchBar respondsToSelector:@selector(setUsesEmbeddedAppearance:)])
		[_searchBar setUsesEmbeddedAppearance:true];
	_searchBar.delegate = self;	
	
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShowWithNotification:) name:UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardWillHideWithNotification:) name:UIKeyboardWillHideNotification object:nil];
	
	return self;
}

-(void)viewDidLoad
{
	self.navigationItem.title = @"Applications";
	
	UIEdgeInsets insets = UIEdgeInsetsMake(44.0f, 0, 0, 0);
	_tableView.contentInset = insets;
	_tableView.contentOffset = CGPointMake(0, 12.0f);
	insets.top = 0;
	_tableView.scrollIndicatorInsets = insets;
	_searchBar.frame = CGRectMake(0, -44.0f, _tableView.bounds.size.width, 44.0f);
	
	[_tableView addSubview:_searchBar];
	[self.view addSubview:_tableView];	
	[super viewDidLoad];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_searchBar resignFirstResponder];
}

-(void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_searchBar.delegate = nil;
	_tableView.delegate = nil;
	[_searchBar release];
	[_dataSource release]; // tableview will be released by dataSource
	[super dealloc];	
}

-(void)keyboardWillShowWithNotification:(NSNotification*)notification
{
	[UIView beginAnimations:nil context:nil];
	NSDictionary* userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:(UIViewAnimationCurve)[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
	CGRect keyboardFrame = CGRectZero;
	[[userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
	UIEdgeInsets insets = UIEdgeInsetsMake(44.0f, 0, keyboardFrame.size.height, 0);
	_tableView.contentInset = insets;
	insets.top = 0;
	_tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];	
}

- (void)keyboardWillHideWithNotification:(NSNotification *)notification
{
	[UIView beginAnimations:nil context:nil];
	NSDictionary* userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:(UIViewAnimationCurve)[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
    UIEdgeInsets insets = UIEdgeInsetsMake(44.0f, 0, 0, 0);
	_tableView.contentInset = insets;
    insets.top = 0.0f;
    _tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];
}
#pragma mark #endregion [ Controller ]

#pragma mark #region [ UISearchBar ]

-(void)searchBarTextDidBeginEditing:(UISearchBar*)searchBar
{
	[_searchBar setShowsCancelButton:true animated:true];
}

-(void)searchBarTextDidEndEditing:(UISearchBar*)searchBar
{
	[_searchBar setShowsCancelButton:false animated:true];
}

-(void)searchBarSearchButtonClicked:(UISearchBar*)searchBar
{
	[_searchBar resignFirstResponder];
}

-(void)searchBarCancelButtonClicked:(UISearchBar*)searchBar
{
	_searchBar.text = nil;
	[self updateDataSource:nil];	
	[_searchBar resignFirstResponder];
	_tableView.contentOffset = CGPointMake(0, 12.0f);
}

-(void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText
{
	[self updateDataSource:searchText];
	_tableView.contentOffset = CGPointMake(0, -44.0f);
}

#pragma mark #endregion [ UISearchBar ]

#pragma mark #region [ UITableViewDelegate ]
-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
	
	// Need to mimic what PSListController does when it handles didSelectRowAtIndexPath
	// otherwise the child controller won't load
	OpenNotifierIconsController* controller = [[[OpenNotifierIconsController alloc] 
		initWithAppName:cell.textLabel.text
		identifier:[_dataSource displayIdentifierForIndexPath:indexPath]
		] autorelease];
	
	controller.rootController = self.rootController;
	controller.parentController = self;	
	
	[self pushController:controller];
	[tableView deselectRowAtIndexPath:indexPath animated:true];
}
#pragma mark #endregion [ UITableViewDelegate ]

@end
#pragma mark #endregion [ OpenNotifierAppsController ]

#pragma mark #region [ OpenNotifierIconsController ]
@implementation OpenNotifierIconsController

#pragma mark #region [ Controller ]
-(id)initWithAppName:(NSString*)appName identifier:(NSString*)identifier
{
	_appName = appName;
	_identifier = identifier;	
	return [self init];
}

-(id)init
{
	if ((self = [super init]) == nil) return nil;
	
	if (!defaultIcon) defaultIcon = [[[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:@"com.apple.WebSheet"] retain];
	if (!cachedIcons) cachedIcons = [[NSMutableDictionary dictionary] retain];				
	if (!statusIcons) 
	{
		statusIcons = [[NSMutableArray array] retain];	
		NSRegularExpression* regex = [[NSRegularExpression regularExpressionWithPattern:SilverIconRegexPattern
			options:NSRegularExpressionCaseInsensitive error:nil] retain];	
			
		for (NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:iconPath error:nil])
		{				
			NSTextCheckingResult* match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
			if (!match) continue;
			NSString* name = [path substringWithRange:[match rangeAtIndex:1]];	
			if (![statusIcons containsObject:name]) [statusIcons addObject:name];
		}
		[regex release];
		
		[statusIcons sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];	
	}
	
	_application = [preferences.applications objectForKey:_identifier];
	
	return self;
}

-(void)viewDidLoad
{
	[super viewDidLoad];
	[self setTitle:_appName];
}

#pragma mark #endregion

#pragma mark #region [ UITableViewDatasource ]

-(id)specifiers 
{
	if (_specifiers) return _specifiers;
	
	_specifiers = [[NSMutableArray array] retain];
			
	for (NSString* name in statusIcons)
	{
		PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil 
			detail:[OpenNotifierIconSettingsController class] cell:PSLinkListCell edit:nil];
					
		[specifier setProperty:name forKey:PSIDKey];
		
		[specifier setProperty:[ONIconCell class] forKey:PSCellClassKey];
		[specifier setProperty:_identifier forKey:ONAppIdentifierKey];
	
		[_specifiers addObject:specifier];
	}
	
	return _specifiers;
}

#pragma mark #endregion

@end
#pragma mark #endregion

#pragma mark #region [ OpenNotifierIconSettingsController ]
@implementation OpenNotifierIconSettingsController

-(id)readPreferenceValue:(PSSpecifier*)specifier
{	
	NSString* key = specifier.identifier;	
	ONApplication* app = [preferences getApplication:[self.specifier propertyForKey:ONAppIdentifierKey]];
	if ([key isEqualToString:ONEnabledKey]) 
	{
		return NSBool(app && [app containsIcon:[self.specifier propertyForKey:PSIDKey]]);		
	}
	else if ([key isEqualToString:ONIconAlignmentKey])
	{
		ONApplicationIcon* icon = [app.icons objectForKey:self.specifier.identifier];
		ONIconAlignment alignment = icon ? icon.alignment : ONIconAlignmentDefault;
		return [NSNumber numberWithUnsignedInteger:alignment];		
	}
		
	return nil;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	NSString* identifier = [self.specifier propertyForKey:ONAppIdentifierKey];
	NSString* iconName = self.specifier.name;
		
	if ([key isEqualToString:ONEnabledKey]) 
	{
		if (![value boolValue]) [preferences removeIcon:iconName fromApplication:identifier];
		else [preferences addIcon:iconName forApplication:identifier];
		[self reloadSpecifiers];
	}
	else if ([key isEqualToString:ONIconAlignmentKey])
	{
		ONApplicationIcon* icon = [preferences getIcon:iconName forApplication:identifier];
		if (icon) icon.alignment = [value intValue];
	}
		
	[preferences save];	
	[(PSListController*)self.parentController reloadSpecifier:self.specifier animated:false];
}

-(void)processIconAlignmentGroup:(bool)enabled
{
	// Alignment Radio Group
	if (enabled)
	{	
		PSSpecifier* groupSpecifier = [PSSpecifier groupSpecifierWithName:@"Alignment"];
		[groupSpecifier setProperty:ONIconAlignmentKey forKey:PSKeyNameKey];
		[groupSpecifier setProperty:NSTrue forKey:PSIsRadioGroupKey];
		[_specifiers addObject:groupSpecifier];
				
		NSNumber* alignment = [self readPreferenceValue:groupSpecifier];
		
		for (uint i = 0; i < 3; i++)
		{
			NSString* title;
			switch (i) 
			{
				case 1: title = @"Force Left"; break;
				case 2: title = @"Force Right"; break;
				default: title = @"Default"; break;
			}
		
			PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:nil detail:nil cell:PSListItemCell edit:nil];
			[specifier setProperty:ONIconAlignmentKey forKey:PSKeyNameKey];
			
			NSNumber* value = [NSNumber numberWithUnsignedInteger:i];
			[specifier setProperty:value forKey:PSValueKey];
			
			if ([value isEqual:alignment]) [groupSpecifier setProperty:specifier forKey:PSRadioGroupCheckedSpecifierKey];
			
			[_specifiers addObject:specifier];
		}
	}
}

-(id)specifiers 
{
	if (_specifiers) return _specifiers;
	
	ONApplication* app = [preferences getApplication:[self.specifier propertyForKey:ONAppIdentifierKey]];		
	_specifiers = [[NSMutableArray array] retain];

	PSSpecifier* specifier;
	
	// Enabled Switch
	specifier = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self 
		set:SELSetPreferenceValue
		get:SELGetPreferenceValue 
		detail:nil cell:PSSwitchCell edit:nil
	];					
	[specifier setProperty:ONEnabledKey forKey:PSIDKey];
	[_specifiers addObject:specifier];
	
	bool enabled = app && [app containsIcon:[self.specifier propertyForKey:PSIDKey]];
	[self processIconAlignmentGroup:enabled];
		
	return _specifiers;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	
	PSSpecifier* specifier = [self specifierAtIndex:[self indexForIndexPath:indexPath]];
	if (specifier && [[specifier propertyForKey:PSKeyNameKey] isEqualToString:ONIconAlignmentKey]) 
	{
		[self setPreferenceValue:[specifier propertyForKey:PSValueKey] specifier:[self specifierForID:ONIconAlignmentKey]];
	}	
}

@end
#pragma mark #endregion