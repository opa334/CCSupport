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

#import <Preferences/PSListController.h>

#import <ControlCenterUI/CCUIModuleSettings.h>
#import <ControlCenterUI/CCUIModuleInstance.h>
#import <ControlCenterUI/CCUIModuleInstanceManager.h>
#import <ControlCenterUI/CCUIModuleCollectionViewController.h>
#import <ControlCenterUI/CCUIModularControlCenterViewController.h>
#import <ControlCenterUI/CCUIModuleSettingsManager.h>

#import <ControlCenterServices/CCSModuleMetadata.h>
#import <ControlCenterServices/CCSModuleRepository.h>
#import <ControlCenterServices/CCSModuleSettingsProvider.h>

@protocol DynamicSizeModule
@optional
- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation;
@end

@interface CCUIModuleInstanceManager (CCSupport)
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier;
@end

@interface CCUISettingsModuleDescription : NSObject
@property(readonly, copy, nonatomic) NSString *displayName;
@end

//CCUISettingsModulesController on iOS 11-13
//CCUISettingsListController on iOS 13

@protocol SettingsControllerSharedAcrossVersions
@property(nonatomic) NSDictionary* fixedModuleIcons; //NEW
@property(nonatomic, retain) NSDictionary* preferenceClassForModuleIdentifiers; //NEW
- (void)_repopulateModuleData;
- (id)_identifierAtIndexPath:(id)arg1;
@end

@interface CCUISettingsModulesController : UITableViewController <SettingsControllerSharedAcrossVersions>
@end

@interface CCUISettingsListController : PSListController <SettingsControllerSharedAcrossVersions>
@end

@interface SBHomeScreenViewController : UIViewController
@end
