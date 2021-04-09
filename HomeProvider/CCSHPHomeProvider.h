#import "CCSModuleProvider.h"
#import "HomeControlCenterModule.h"

@interface CCSHPHomeProvider : NSObject <CCSModuleProvider>
{
	HUCCControlCenterModule* _module;
	UIImage* _settingsIcon;
}

@end
