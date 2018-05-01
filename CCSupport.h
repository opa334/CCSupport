@interface CCModuleSettingsProvider : NSObject
+ (NSArray*)_defaultFixedModuleIdentifiers;
@end

@interface CCSModuleRepository : NSObject
@property (assign,nonatomic) bool ignoreWhitelist;
@end

@interface CCUISettingsModuleDescription : NSObject
@property(readonly, copy, nonatomic) NSString *displayName;
@end

@interface CCUISettingsModulesController : UITableViewController
@property(nonatomic) NSDictionary* fixedModuleIcons;
- (void)_repopulateModuleData;
@end

@interface SBHomeScreenViewController : UIViewController
@end
