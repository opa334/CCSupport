typedef struct CCUILayoutSize {
	unsigned long long width;
	unsigned long long height;
} CCUILayoutSize;

enum
{
	CCOrientationPortrait = 0,
	CCOrientationLandscape = 1
};

@protocol DynamicSizeModule
@optional
- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation;
@end

@interface CCModuleSettingsProvider : NSObject
+ (NSArray*)_defaultFixedModuleIdentifiers;
@end

@interface CCSModuleMetadata : NSObject
@property (nonatomic,copy,readonly) NSURL* moduleBundleURL;
@end

@interface CCSModuleRepository : NSObject
@property (assign,nonatomic) bool ignoreWhitelist;
- (void)_updateAllModuleMetadata;
- (CCSModuleMetadata*)moduleMetadataForModuleIdentifier:(id)arg1;
@end

@interface CCUISettingsModuleDescription : NSObject
@property(readonly, copy, nonatomic) NSString *displayName;
@end

@interface CCUISettingsModulesController : UITableViewController
@property(nonatomic) NSDictionary* fixedModuleIcons; //NEW
@property(nonatomic, retain) NSDictionary* preferenceClassForModuleIdentifiers; //NEW
- (void)_repopulateModuleData;
- (id)_identifierAtIndexPath:(id)arg1;
@end

@interface CCUIModuleSettings : NSObject
@end

@interface CCUIModuleInstance : NSObject
@property (nonatomic,readonly) CCSModuleMetadata* metadata;
@property (nonatomic,readonly) NSObject<DynamicSizeModule>* module;
@end

@interface CCUIModuleInstanceManager : NSObject
+ (id)sharedInstance;
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier; //NEW
@end

@interface CCUIModuleCollectionViewController : UIViewController
- (void)_refreshPositionProviders;
@end

@interface CCUIModularControlCenterViewController : UIViewController
+ (CCUIModuleCollectionViewController*)_sharedCollectionViewController;
@end

@interface SBHomeScreenViewController : UIViewController
@end

#if defined __cplusplus
extern "C" {
#endif

CGImageRef LICreateIconForImage(CGImageRef image, int variant, int precomposed);

#if defined __cplusplus
};
#endif
