#define ONSchemaVersion 1

enum
{
	ONIconAlignmentDefault = 0,
	ONIconAlignmentLeft = 1,
	ONIconAlignmentRight = 2
};
typedef NSUInteger ONIconAlignment;

@interface ONApplicationIcon : NSObject
{
	NSMutableDictionary* _dictionary;
}
@property(assign, nonatomic) ONIconAlignment alignment;
-(NSMutableDictionary*)toDictionary;
@end

@interface ONApplication : NSObject
{
	NSMutableDictionary* _dictionary;
}
@property(retain, nonatomic) NSMutableDictionary* icons;
-(NSMutableDictionary*)toDictionary;
-(bool)containsIcon:(NSString*)iconName;
@end

@interface ONPreferences : NSObject
{
	NSMutableDictionary* _data;
	NSMutableDictionary* _applications;
}
@property(readonly, nonatomic) NSMutableDictionary* applications;
@property(assign) bool enabled;
@property(assign) bool iconsOnLeft;
@property(assign) bool silentModeEnabled;
@property(assign) bool silentIconOnLeft;
@property(assign) bool vibrateModeEnabled;
@property(assign) bool vibrateIconOnLeft;

+(id)sharedInstance;

-(ONApplication*)getApplication:(NSString*)identifer;
-(void)removeApplication:(NSString*)identifer;

-(id)addIcon:(NSString*)iconName forApplication:(NSString*)identifer;
-(void)removeIcon:(NSString*)iconName fromApplication:(NSString*)identifer;
-(ONApplicationIcon*)getIcon:(NSString*)iconName forApplication:(NSString*)identifer;

-(void)reload;
-(void)save;

@end