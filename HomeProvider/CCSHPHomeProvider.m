#import "CCSHPHomeProvider.h"
#import "CCSHPPreferencesListController.h"

#import "../Defines.h"

NSBundle* homeCCModuleBundle;
NSBundle* CCSupportBundle;

@implementation CCSHPHomeProvider

- (NSUInteger)numberOfProvidedModules
{
	if(homeCCModuleBundle)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}

- (NSString*)identifierForModuleAtIndex:(NSUInteger)index
{
	return @"com.opa334.CCSupport.Home.ControlCenter";
}

- (id)moduleInstanceForModuleIdentifier:(NSString*)identifier
{
	return [[NSClassFromString(@"CCSHPControlCenterModule") alloc] init];
}

- (NSString*)displayNameForModuleIdentifier:(NSString*)identifier
{
	return [CCSupportBundle localizedStringForKey:@"Home Controls" value:@"Home Controls" table:nil];
}

- (NSString*)associatedBundleIdentifierForModuleWithIdentifier:(NSString*)identifier
{
	return @"com.apple.Home";
}

- (UIImage*)settingsIconForModuleIdentifier:(NSString*)identifier
{
	if(!_settingsIcon)
	{
		_settingsIcon = [UIImage imageNamed:@"SettingsIcon" inBundle:homeCCModuleBundle compatibleWithTraitCollection:nil];
	}
	return _settingsIcon;
}

- (BOOL)providesListControllerForModuleIdentifier:(NSString*)identifier
{
	return YES;
}

- (id)listControllerForModuleIdentifier:(NSString*)identifier
{
	return [[NSClassFromString(@"CCSHPPreferencesListController") alloc] init];
}

@end

extern void initCCSHPControlCenterModule();
extern void initHardCodedFixes();

__attribute__((constructor))
static void init(void)
{
	if (@available(iOS 14, *))
	{
		CCSupportBundle = [NSBundle bundleWithPath:CCSupportBundlePath];
		homeCCModuleBundle = [NSBundle bundleWithPath:@"/System/Library/ControlCenter/Bundles/HomeControlCenterModule.bundle"];

		if([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"])
		{
			[homeCCModuleBundle load];

			initCCSHPControlCenterModule();
			initHardCodedFixes();
		}
	}
	else
	{
		homeCCModuleBundle = nil;
		return;
	}
}