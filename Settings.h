#import "Tweak.h"
#import "Preferences.h"
#import <Preferences/Preferences.h>
#import <AppList/AppList.h>

@interface OpenNotifierSettingsRootController: PSListController
@end

@interface OpenNotifierAppsController : PSViewController <UITableViewDelegate, UISearchBarDelegate>
{
	UITableView* _tableView;
	ALApplicationTableDataSource* _dataSource;
	UISearchBar* _searchBar;
}
@end

@interface OpenNotifierIconsController : PSListController
{
	NSString* _appName;	
	NSString* _identifier;
	ONApplication* _application;
}
-(id)initWithAppName:(NSString*)appName identifier:(NSString*)identifier;
@end

@interface OpenNotifierIconSettingsController : PSListController
@end
