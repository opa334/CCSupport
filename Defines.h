#import <rootless.h>

#define DefaultModuleConfigurationPath @"/var/mobile/Library/ControlCenter/ModuleConfiguration.plist"
#define CCSupportModuleConfigurationPath ROOT_PATH_NS(@"/var/mobile/Library/ControlCenter/ModuleConfiguration_CCSupport.plist")
#define DefaultModuleOrderPath @"/System/Library/PrivateFrameworks/ControlCenterServices.framework/DefaultModuleOrder~%@.plist"

#define CCSupportBundlePath ROOT_PATH_NS(@"/Library/Application Support/CCSupport")
#define CCSupportModulesPath ROOT_PATH_NS(@"/Library/ControlCenter/Bundles")
#define CCSupportProvidersPath ROOT_PATH_NS(@"/Library/ControlCenter/CCSupport_Providers")

#define iOS15_WhitelistedFixedModuleIdentifiers @[@"com.apple.replaykit.AudioConferenceControlCenterModule", @"com.apple.replaykit.VideoConferenceControlCenterModule"]

#ifndef kCFCoreFoundationVersionNumber_iOS_15_0
#define kCFCoreFoundationVersionNumber_iOS_15_0 1854
#endif