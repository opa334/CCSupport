#import "HomeControlCenterModule.h"
#import <ControlCenterUI/ControlCenterUI-Structs.h>

%subclass CCSHPControlCenterModule : HUCCControlCenterModule

%new
- (CCUILayoutSize)moduleSizeForOrientation:(int)orientation
{
	CCUILayoutSize size;

	NSDictionary* preferences = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.opa334.CCSupport.HomeControlsPrefs"];

	if (orientation == 0) {
		NSNumber* widthNum = [preferences objectForKey:@"PortraitWidth"];
		NSNumber* heightNum = [preferences objectForKey:@"PortraitHeight"];

		if (widthNum) {
			size.width = [widthNum unsignedLongLongValue];
		}
		else {
			size.width = 4;
		}

		if (heightNum) {
			size.height = [heightNum unsignedLongLongValue];
		}
		else {
			size.height = 2;
		}
	}
	else {
		NSNumber* widthNum = [preferences objectForKey:@"LandscapeWidth"];
		NSNumber* heightNum = [preferences objectForKey:@"LandscapeHeight"];

		if (widthNum) {
			size.width = [widthNum unsignedLongLongValue];
		}
		else {
			size.width = 2;
		}

		if (heightNum) {
			size.height = [heightNum unsignedLongLongValue];
		}
		else {
			size.height = 3;
		}
	}

	return size;
}

%end

void initCCSHPControlCenterModule()
{
	%config(generator=internal);
	%init;
}