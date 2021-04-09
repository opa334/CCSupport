#if defined __cplusplus
extern "C" {
#endif

CGImageRef LICreateIconForImage(CGImageRef image, int variant, int precomposed);

#if defined __cplusplus
};
#endif

enum
{
	CCOrientationPortrait = 0,
	CCOrientationLandscape = 1
};

#import "CCSModuleProvider.h"
#import <Preferences/PSListController.h>

#import <ControlCenterUI/CCUIModuleSettings.h>
#import <ControlCenterUI/CCUIModuleInstance.h>
#import <ControlCenterUI/CCUIModuleInstanceManager.h>
#import <ControlCenterUI/CCUIModuleCollectionViewController.h>
#import <ControlCenterUI/CCUIModularControlCenterViewController.h>
#import <ControlCenterUI/CCUIModuleSettingsManager.h>
#import <ControlCenterUI/CCUIContentModuleContainerViewController.h>

#import <ControlCenterServices/CCSModuleMetadata.h>
#import <ControlCenterServices/CCSModuleRepository.h>
#import <ControlCenterServices/CCSModuleSettingsProvider.h>

#import <ControlCenterUIKit/CCUIContentModuleContext.h>
#import <ControlCenterUIKit/CCUIContentModule.h>

@protocol DynamicSizeModule
@optional
- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation;
@end

@interface CCUIModuleInstanceManager (CCSupport)
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier;
@end

@interface CCUIModuleSettings (CCSupport)
@property (nonatomic, assign) BOOL ccs_usesDynamicSize;
@end

@interface CCSModuleMetadata (CCSupport)
@property(nonatomic, assign) BOOL ccs_moduleFromProvider;
@end

@interface CCUISettingsModuleDescription : NSObject
@property(readonly, copy, nonatomic) NSString *displayName;
@end

@interface CCSModuleRepository (iOS12Up)
- (void)_queue_updateAllModuleMetadata;
@end

@interface CCSModuleRepository (CCSupport)
- (NSArray*)ccshook_loadAllModuleMetadataWithOrig:(NSArray*)orig;
@end


//CCUISettingsModulesController on iOS 11-13
//CCUISettingsListController on iOS 13

@protocol SettingsControllerSharedAcrossVersions
@property(nonatomic) NSDictionary* fixedModuleIcons; //NEW
@property(nonatomic, retain) NSDictionary* preferenceClassForModuleIdentifiers; //NEW
- (void)_repopulateModuleData;
- (id)_identifierAtIndexPath:(id)arg1;
- (UITableView*)ccs_getTableView;
- (void)ccs_unselectSelectedRow;
- (void)ccs_resetButtonPressed;
- (CCUISettingsModuleDescription*)_descriptionForIdentifier:(NSString*)identifier;
@end

@interface CCUISettingsModulesController : UITableViewController <SettingsControllerSharedAcrossVersions>
@end

@interface CCUISettingsListController : PSListController <SettingsControllerSharedAcrossVersions>
@end

@interface SBHomeScreenViewController : UIViewController
@end

@interface CCSModuleProviderManager : NSObject
@property (nonatomic) NSDictionary* moduleProvidersByIdentifier;
@property (nonatomic) NSDictionary* providerToModuleCache;
+ (instancetype)sharedInstance;
- (void)_reloadProviders;
- (void)_populateProviderToModuleCache;
- (NSObject<CCSModuleProvider>*)_moduleProviderForModuleWithIdentifier:(NSString*)moduleIdentifier;
- (CCSModuleMetadata*)_metadataForProvidedModuleWithIdentifier:(NSString*)identifier fromProvider:(NSObject<CCSModuleProvider>*)provider;
- (NSMutableSet*)_allProvidedModuleIdentifiers;
- (BOOL)doesProvideModule:(NSString*)moduleIdentifier;
- (NSMutableArray*)metadataForAllProvidedModules;
- (id)moduleInstanceForModuleIdentifier:(NSString*)identifier;
- (BOOL)providesListControllerForModuleIdentifier:(NSString*)identifier;
- (id)listControllerForModuleIdentifier:(NSString*)identifier;
- (NSString*)displayNameForModuleIdentifier:(NSString*)identifier;
- (UIImage*)settingsIconForModuleIdentifier:(NSString*)identifier;
- (void)reload;
@end

@interface CCSProvidedListController : NSObject //placeholder
@end

@interface NSValue (ControlCenterUI)
+ (NSValue*)ccui_valueWithLayoutSize:(CCUILayoutSize)layoutSize;
- (CCUILayoutSize)ccui_sizeValue;
@end