@protocol CCSModuleProvider
@required
- (NSUInteger)numberOfProvidedModules;
- (NSString*)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString*)identifier;
- (NSString*)displayNameForModuleIdentifier:(NSString*)identifier;
@optional
- (NSSet*)supportedDeviceFamiliesForModuleWithIdentifier:(NSString*)identifier;
- (NSSet*)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString*)identifier;
- (NSString*)associatedBundleIdentifierForModuleWithIdentifier:(NSString*)identifier;
- (NSString*)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString*)identifier;
- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString*)identifier;
- (UIImage*)settingsIconForModuleIdentifier:(NSString*)identifier;
- (BOOL)providesListControllerForModuleIdentifier:(NSString*)identifier;
- (id)listControllerForModuleIdentifier:(NSString*)identifier;
@end