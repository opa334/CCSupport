#import "../CCSupport.h"

// Fixes that are needed because the ControlCenter frameworks are hardcoded for com.apple.Home.ControlCenter

%hook CCUIContentModuleContainerViewController

BOOL ccs_shouldSpoofOnceAsHomeControlCenter = NO;

- (NSString *)moduleIdentifier
{
	NSString *orig = %orig;

	if(ccs_shouldSpoofOnceAsHomeControlCenter && orig){ 
		ccs_shouldSpoofOnceAsHomeControlCenter = NO;
		return @"com.apple.Home.ControlCenter";
	}

	return orig;
}

- (void)expandModule
{
	NSString *orgModuleIdentifier = self.moduleIdentifier;
	if([orgModuleIdentifier isEqualToString:@"com.opa334.CCSupport.Home.ControlCenter"]){ 
		ccs_shouldSpoofOnceAsHomeControlCenter = YES;
		%orig;
		ccs_shouldSpoofOnceAsHomeControlCenter = NO;
	}
	else{ 
		%orig;
	}
}

%end

void initHardCodedFixes()
{
	%config(generator=internal);
	%init();
}