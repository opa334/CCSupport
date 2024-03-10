#import <libroot.h>

#define DefaultModuleConfigurationPath @"/var/mobile/Library/ControlCenter/ModuleConfiguration.plist"
#define CCSupportModuleConfigurationPath JBROOT_PATH_NSSTRING(@"/var/mobile/Library/ControlCenter/ModuleConfiguration_CCSupport.plist")
#define DefaultModuleOrderPath @"/System/Library/PrivateFrameworks/ControlCenterServices.framework/DefaultModuleOrder~%@.plist"

#define CCSupportBundlePath JBROOT_PATH_NSSTRING(@"/Library/Application Support/CCSupport")
#define CCSupportModulesPath JBROOT_PATH_NSSTRING(@"/Library/ControlCenter/Bundles")
#define CCSupportProvidersPath JBROOT_PATH_NSSTRING(@"/Library/ControlCenter/CCSupport_Providers")

#define iOS15_WhitelistedFixedModuleIdentifiers @[@"com.apple.replaykit.AudioConferenceControlCenterModule", @"com.apple.replaykit.VideoConferenceControlCenterModule"]

#ifndef kCFCoreFoundationVersionNumber_iOS_15_0
#define kCFCoreFoundationVersionNumber_iOS_15_0 1854
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_16_0
#define kCFCoreFoundationVersionNumber_iOS_16_0 1932.101
#endif