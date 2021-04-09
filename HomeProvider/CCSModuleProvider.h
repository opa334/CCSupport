@protocol CCSModuleProvider
@required
- (NSUInteger)numberOfProvidedModules;
- (NSString*)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString*)identifier;
- (NSString*)displayNameForModuleIdentifier:(NSString*)identifier;
@optional
//Properties of CCSModuleMetadata: https://developer.limneos.net/index.php?ios=13.1.3&framework=ControlCenterServices.framework&header=CCSModuleMetadata.h
- (NSSet*)supportedDeviceFamiliesForModuleWithIdentifier:(NSString*)identifier;
- (NSSet*)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString*)identifier;
- (NSString*)associatedBundleIdentifierForModuleWithIdentifier:(NSString*)identifier;
- (NSString*)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString*)identifier;
- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString*)identifier;

//Return icon that shows for the module in settings
- (UIImage*)settingsIconForModuleIdentifier:(NSString*)identifier;

//Return whether the module has a settings page
- (BOOL)providesListControllerForModuleIdentifier:(NSString*)identifier;

//Return the PSListController instance for the module settings page
- (id)listControllerForModuleIdentifier:(NSString*)identifier;
@end