#import "CCSupport.h"
#import "Defines.h"
#import <objc/runtime.h>

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NSString* getRootPath(void)
{
	static NSString* rootPath = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^
	{
		NSFileManager* fileManager = [NSFileManager defaultManager];
		NSDictionary* attributes = [fileManager attributesOfItemAtPath:@"/var/jb" error:nil];
		if(attributes)
		{
			NSString* fileType = attributes[NSFileType];
			if([fileType isEqualToString:NSFileTypeSymbolicLink])
			{
				rootPath = [fileManager destinationOfSymbolicLinkAtPath:@"/var/jb" error:nil];
			}
		}
		if(!rootPath)
		{
			rootPath = @"/";
		}
    });

	return rootPath;
}

NSArray* fixedModuleIdentifiers; //Identifiers of (normally) fixed modules
NSBundle* CCSupportBundle; //Bundle for icons and localization (only needed / initialized in settings)
NSDictionary* englishLocalizations; //English localizations for fallback
BOOL isSpringBoard; //Are we SpringBoard???

static inline BOOL obj_hasIvar(id object, const char* ivarName)
{
	Ivar ivar = class_getInstanceVariable(object_getClass(object), ivarName);
	if(ivar)
	{
		return YES;
	}
	return NO;
}

//Get localized string for given key
NSString* localize(NSString* key)
{
	if([key isEqualToString:@"MediaControlsAudioModule"]) //Fix Volume name on 13 and above
	{
		key = @"AudioModule";
	}
	
	NSString* localizedString = [CCSupportBundle localizedStringForKey:key value:nil table:nil];
	if([localizedString isEqualToString:key])
	{
		if(!englishLocalizations)
		{
			englishLocalizations = [NSDictionary dictionaryWithContentsOfFile:[CCSupportBundle pathForResource:@"Localizable" ofType:@"strings" inDirectory:@"en.lproj"]];
		}

		//If no localization was found, fallback to english
		NSString* engString = [englishLocalizations objectForKey:key];

		if(engString)
		{
			return engString;
		}
		else
		{
			//If an english localization was not found, just return the key itself
			return key;
		}
	}

	return localizedString;
}

UIImage* moduleIconForImage(UIImage* image)
{
	long long imageVariant;

	CGFloat screenScale = UIScreen.mainScreen.scale;

	if(screenScale >= 3.0)
	{
		imageVariant = 34;
	}
	else if(screenScale >= 2.0)
	{
		imageVariant = 17;
	}
	else
	{
		imageVariant = 4;
	}

	CGImageRef liIcon = LICreateIconForImage([image CGImage], imageVariant, 0);

	return [[UIImage alloc] initWithCGImage:liIcon scale:screenScale orientation:0];
}

//Get fixed module identifiers from device specific plist (Return value: whether the plist was modified or not)
BOOL loadFixedModuleIdentifiers()
{
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken,
	^{
		//This method is called before the hook of it is initialized, that's why we can get the actual fixed identifiers here
		NSMutableArray* fixedModuleIdentifiersMutable = ((NSArray*)[%c(CCSModuleSettingsProvider) _defaultFixedModuleIdentifiers]).mutableCopy;
		if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0)
		{
			[fixedModuleIdentifiersMutable removeObjectsInArray:iOS15_WhitelistedFixedModuleIdentifiers];
		}
		fixedModuleIdentifiers = fixedModuleIdentifiersMutable.copy;
	});

	//If this array contains less than 7 objects, something was modified with no doubt
	return ([fixedModuleIdentifiers count] < 7);
}

@implementation CCSModuleProviderManager

- (instancetype)init
{
	self = [super init];

	[self _reloadProviders];
	[self _populateProviderToModuleCache];

	return self;
}

+ (instancetype)sharedInstance
{
	static CCSModuleProviderManager *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^
	{
		sharedInstance = [[CCSModuleProviderManager alloc] init];
	});
	return sharedInstance;
}

- (void)_reloadProviders
{
	NSMutableDictionary* newModuleIdentifiersByIdentifier = [NSMutableDictionary new];

	NSString* providersPath = [getRootPath() stringByAppendingPathComponent:ProviderBundlePath];
	NSURL* providersURL = [NSURL fileURLWithPath:providersPath isDirectory:YES];
	NSArray<NSURL*>* contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:providersURL includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:0 error:nil];
	for(NSURL* itemURL in contents)
	{
		NSNumber* isDirectory;
		[itemURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

		if(![itemURL.pathExtension isEqualToString:@"bundle"] || ![isDirectory boolValue])
		{
			continue;
		}

		NSBundle* bundle = [NSBundle bundleWithURL:itemURL];
		NSError* error;
		BOOL loaded = [bundle loadAndReturnError:&error];
		if(!loaded)
		{
			continue;
		}

		NSString* providerIdentifier = bundle.bundleIdentifier;
		Class providerClass = bundle.principalClass;

		if(providerClass)
		{
			NSObject<CCSModuleProvider>* provider = [[providerClass alloc] init];
			[newModuleIdentifiersByIdentifier setObject:provider forKey:providerIdentifier];
		}
	}

	self.moduleProvidersByIdentifier = [newModuleIdentifiersByIdentifier copy];
}

- (void)_populateProviderToModuleCache
{
	if(!self.moduleProvidersByIdentifier)
	{
		[self _reloadProviders];
	}

	NSMutableDictionary* newProviderToModuleCache = [NSMutableDictionary new];

	for(NSString* key in [self.moduleProvidersByIdentifier allKeys])
	{
		NSObject<CCSModuleProvider>* provider = [self.moduleProvidersByIdentifier objectForKey:key];

		NSMutableArray* moduleIdentifiers = [NSMutableArray new];

		NSUInteger moduleNumber = [provider numberOfProvidedModules];
		for(NSUInteger i = 0; i < moduleNumber; i++)
		{
			NSString* moduleIdentifier = [provider identifierForModuleAtIndex:i];
			if(moduleIdentifier)
			{
				[moduleIdentifiers addObject:moduleIdentifier];
			}
		}

		[newProviderToModuleCache setObject:[moduleIdentifiers copy] forKey:key];
	}

	self.providerToModuleCache = [newProviderToModuleCache copy];
}

- (NSObject<CCSModuleProvider>*)_moduleProviderForModuleWithIdentifier:(NSString*)moduleIdentifier
{
	if(!self.moduleProvidersByIdentifier)
	{
		[self _reloadProviders];
	}
	if(!self.providerToModuleCache)
	{
		[self _populateProviderToModuleCache];
	}

	for(NSString* moduleProviderIdentifier in self.providerToModuleCache)
	{
		NSArray* providedModuleIdentifiers = [self.providerToModuleCache objectForKey:moduleProviderIdentifier];
		if([providedModuleIdentifiers containsObject:moduleIdentifier])
		{
			return [self.moduleProvidersByIdentifier objectForKey:moduleProviderIdentifier];
		}
	}

	return nil;
}

- (CCSModuleMetadata*)_metadataForProvidedModuleWithIdentifier:(NSString*)identifier fromProvider:(NSObject<CCSModuleProvider>*)provider
{
	NSSet *supportedDeviceFamilies, *requiredDeviceCapabilities;
	NSString *associatedBundleIdentifier, *associatedBundleMinimumVersion;
	NSUInteger visibilityPreference = 0;

	if([provider respondsToSelector:@selector(supportedDeviceFamiliesForModuleWithIdentifier:)])
	{
		supportedDeviceFamilies = [provider supportedDeviceFamiliesForModuleWithIdentifier:identifier];
	}
	else
	{
		supportedDeviceFamilies = [NSSet setWithObjects:@1, @2, nil];
	}
	if([provider respondsToSelector:@selector(requiredDeviceCapabilitiesForModuleWithIdentifier:)])
	{
		requiredDeviceCapabilities = [provider requiredDeviceCapabilitiesForModuleWithIdentifier:identifier];
	}
	else
	{
		requiredDeviceCapabilities = [NSSet setWithObjects:@"arm64", nil];
	}
	if([provider respondsToSelector:@selector(associatedBundleIdentifierForModuleWithIdentifier:)])
	{
		associatedBundleIdentifier = [provider associatedBundleIdentifierForModuleWithIdentifier:identifier];
	}
	if([provider respondsToSelector:@selector(associatedBundleMinimumVersionForModuleWithIdentifier:)])
	{
		associatedBundleMinimumVersion = [provider associatedBundleMinimumVersionForModuleWithIdentifier:identifier];
	}
	if([provider respondsToSelector:@selector(visibilityPreferenceForModuleWithIdentifier:)])
	{
		visibilityPreference = [provider visibilityPreferenceForModuleWithIdentifier:identifier];
	}

	NSBundle* bundle = [NSBundle bundleForClass:[provider class]];

	CCSModuleMetadata* metadata = [[%c(CCSModuleMetadata) alloc] _initWithModuleIdentifier:identifier supportedDeviceFamilies:supportedDeviceFamilies requiredDeviceCapabilities:requiredDeviceCapabilities associatedBundleIdentifier:associatedBundleIdentifier associatedBundleMinimumVersion:associatedBundleMinimumVersion visibilityPreference:visibilityPreference moduleBundleURL:bundle.bundleURL];

	return metadata;
}

- (NSMutableSet*)_allProvidedModuleIdentifiers
{
	NSMutableSet* allModuleIdentifiers = [NSMutableSet new];

	for(NSString* providerIdentifier in self.moduleProvidersByIdentifier.allKeys)
	{
		for(NSString* moduleIdentifier in [self.providerToModuleCache objectForKey:providerIdentifier])
		{
			[allModuleIdentifiers addObject:moduleIdentifier];
		}
	}

	return allModuleIdentifiers;
}

- (BOOL)doesProvideModule:(NSString*)moduleIdentifier
{
	NSObject<CCSModuleProvider>* moduleProvider = [self _moduleProviderForModuleWithIdentifier:moduleIdentifier];
	return moduleProvider != nil;
}

- (NSMutableArray*)metadataForAllProvidedModules
{
	NSMutableArray* allMetadata = [NSMutableArray new];

	for(NSString* moduleProviderIdentifier in self.providerToModuleCache)
	{
		NSObject<CCSModuleProvider>* provider = [self.moduleProvidersByIdentifier objectForKey:moduleProviderIdentifier];
		NSArray* providedModuleIdentifiers = [self.providerToModuleCache objectForKey:moduleProviderIdentifier];
		for(NSString* identifier in providedModuleIdentifiers)
		{
			CCSModuleMetadata* metadata = [self _metadataForProvidedModuleWithIdentifier:identifier fromProvider:provider];
			if(metadata)
			{
				[allMetadata addObject:metadata];
			}
		}
	}

	return allMetadata;
}

- (id)moduleInstanceForModuleIdentifier:(NSString*)identifier
{
	NSObject<CCSModuleProvider>* provider = [self _moduleProviderForModuleWithIdentifier:identifier];
	return [provider moduleInstanceForModuleIdentifier:identifier];
}

- (id)listControllerForModuleIdentifier:(NSString*)identifier
{
	NSObject<CCSModuleProvider>* provider = [self _moduleProviderForModuleWithIdentifier:identifier];

	if([provider respondsToSelector:@selector(listControllerForModuleIdentifier:)])
	{
		return [provider listControllerForModuleIdentifier:identifier];
	}

	return nil;
}

- (NSString*)displayNameForModuleIdentifier:(NSString*)identifier
{
	NSObject<CCSModuleProvider>* provider = [self _moduleProviderForModuleWithIdentifier:identifier];
	return [provider displayNameForModuleIdentifier:identifier];
}

- (UIImage*)settingsIconForModuleIdentifier:(NSString*)identifier
{
	NSObject<CCSModuleProvider>* provider = [self _moduleProviderForModuleWithIdentifier:identifier];

	if([provider respondsToSelector:@selector(settingsIconForModuleIdentifier:)])
	{
		return [provider settingsIconForModuleIdentifier:identifier];
	}

	return nil;
}

- (BOOL)providesListControllerForModuleIdentifier:(NSString*)identifier
{
	NSObject<CCSModuleProvider>* provider = [self _moduleProviderForModuleWithIdentifier:identifier];
	
	if([provider respondsToSelector:@selector(providesListControllerForModuleIdentifier:)])
	{
		return [provider providesListControllerForModuleIdentifier:identifier];
	}
	
	return NO;
}

//reloads and if any modules have been removed that are still added in CC, they're removed from the plist
//(this is to prevent the plist from having entries that would otherwise never be removed)
- (void)reload
{
	if(!isSpringBoard)
	{
		[self _populateProviderToModuleCache];
	}
	else
	{
		NSMutableSet* moduleIdentifiersBeforeReload = [self _allProvidedModuleIdentifiers];
		[self _populateProviderToModuleCache];
		NSMutableSet* moduleIdentifiersAfterReload = [self _allProvidedModuleIdentifiers];

		[moduleIdentifiersBeforeReload minusSet:moduleIdentifiersAfterReload];

		//moduleIdentifiersBeforeReload now contains all module identifiers
		//that have been removed from providers since the last reload

		BOOL changed = NO;
		CCSModuleSettingsProvider* settingsProvider = [%c(CCSModuleSettingsProvider) sharedProvider];
		NSMutableArray* orderedUserEnabledModuleIdentifiers = settingsProvider.orderedUserEnabledModuleIdentifiers.mutableCopy;

		for(NSString* removedModuleIdentifier in moduleIdentifiersBeforeReload)
		{
			if([orderedUserEnabledModuleIdentifiers containsObject:removedModuleIdentifier])
			{
				changed = YES;
				[orderedUserEnabledModuleIdentifiers removeObject:removedModuleIdentifier];
			}
		}

		if(changed)
		{
			[settingsProvider setAndSaveOrderedUserEnabledModuleIdentifiers:orderedUserEnabledModuleIdentifiers];
		}
	}	
}

@end

@implementation CCSProvidedListController //placeholder
@end

%group ControlCenterServices

%hook CCSModuleRepository

//Add path for third party bundles to directory urls
+ (NSArray<NSURL*>*)_defaultModuleDirectories
{
	NSArray<NSURL*>* directories = %orig;

	if(directories)
	{
		NSString* originalPathWithoutSytem = [[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System/" withString:@""];
		NSString* rootResolvedPath = [getRootPath() stringByAppendingPathComponent:originalPathWithoutSytem];
		NSURL* thirdPartyURL = [NSURL fileURLWithPath:rootResolvedPath isDirectory:YES];
		return [directories arrayByAddingObject:thirdPartyURL];
	}

	return directories;
}

//Enable non whitelisted modules to be loaded

- (void)_queue_updateAllModuleMetadata	//iOS >=12
{
	if(obj_hasIvar(self, "_ignoreAllowedList")) //iOS >=14
	{
		MSHookIvar<BOOL>(self, "_ignoreAllowedList") = YES;
	}
	else if(obj_hasIvar(self, "_ignoreWhitelist")) //iOS 11-13
	{
		MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
	}
	
	%orig;
}

- (void)_updateAllModuleMetadata //iOS 11
{
	if(![self respondsToSelector:@selector(_queue_updateAllModuleMetadata)])
	{
		MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
	}

	%orig;
}

//Module providers

%new
- (NSArray*)ccshook_loadAllModuleMetadataWithOrig:(NSArray*)orig
{
	//add metadata provided by module providers
	CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
	NSMutableArray* providedMetadata = [providerManager metadataForAllProvidedModules];

	if(!providedMetadata || providedMetadata.count <= 0)
	{
		return orig;
	}

	NSArray* allModuleMetadata = orig;
	NSMutableArray* allModuleMetadataM;

	if([allModuleMetadata respondsToSelector:@selector(addObject:)])
	{
		allModuleMetadataM = (NSMutableArray*)allModuleMetadata;
	}
	else
	{
		allModuleMetadataM = [allModuleMetadata mutableCopy];
	}

	[allModuleMetadataM addObjectsFromArray:providedMetadata];

	return allModuleMetadataM;
}

- (NSArray*)_queue_loadAllModuleMetadata //iOS >=12
{
	NSArray* orig = %orig;
	return [self ccshook_loadAllModuleMetadataWithOrig:orig];
}

- (NSArray*)_loadAllModuleMetadata //iOS 11
{
	NSArray* orig = %orig;
	return [self ccshook_loadAllModuleMetadataWithOrig:orig];
}

%end

// Hacky fix on iOS 15, see below in _queue_loadSettings
%hook NSMutableArray

NSArray* g_mutableArrayPreventRemoval = nil;

- (void)removeObject:(NSObject*)object
{
	if(g_mutableArrayPreventRemoval)
	{
		if([g_mutableArrayPreventRemoval containsObject:object])
		{
			return;
		}
	}

	%orig;
}

%end

%hook CCSModuleSettingsProvider

//Return different configuration plist to not mess everything up when the tweak is not enabled
+ (NSURL*)_configurationFileURL
{
	return [NSURL fileURLWithPath:CCSupportModuleConfigurationPath];
}

//Return empty array for fixed modules
+ (NSMutableArray*)_defaultFixedModuleIdentifiers
{
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0)
	{
		// Fix replaykit modules not showing up on iOS 15
		return iOS15_WhitelistedFixedModuleIdentifiers.mutableCopy;
	}
	else
	{
		return [NSMutableArray array];
	}
}

//Return fixed + non fixed modules
+ (NSMutableArray*)_defaultUserEnabledModuleIdentifiers
{
	NSMutableArray* defaultUserEnabledModuleIdentifiers = [[fixedModuleIdentifiers arrayByAddingObjectsFromArray:%orig] mutableCopy];

	// In iOS 15 the return order of this method is how the modules will be initially ordered on first launch
	// Because CCSupport fucks this order up, we need to sort a few things manually so it appears just like it would on stock
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0)
	{
		// 1. remove com.apple.donotdisturb.DoNotDisturbModule
		[defaultUserEnabledModuleIdentifiers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSString* str, NSUInteger idx, BOOL* stop)
		{
			// for some reason calling removeObject with com.apple.donotdisturb.DoNotDisturbModule does not work
			if([str isEqualToString:@"com.apple.donotdisturb.DoNotDisturbModule"])
			{
				[defaultUserEnabledModuleIdentifiers removeObjectAtIndex:idx];
				*stop = YES;
			}
		}];

		// 2. put com.apple.mediaremote.controlcenter.airplaymirroring after com.apple.control-center.OrientationLockModule
		[defaultUserEnabledModuleIdentifiers removeObject:@"com.apple.mediaremote.controlcenter.airplaymirroring"];
		NSInteger orientationLockModuleIndex = [defaultUserEnabledModuleIdentifiers indexOfObject:@"com.apple.control-center.OrientationLockModule"];
		if(orientationLockModuleIndex != NSNotFound)
		{
			[defaultUserEnabledModuleIdentifiers insertObject:@"com.apple.mediaremote.controlcenter.airplaymirroring" atIndex:orientationLockModuleIndex+1];
		}

		// 3. insert com.apple.FocusUIModule after com.apple.mediaremote.controlcenter.audio
		NSInteger audioIndex = [defaultUserEnabledModuleIdentifiers indexOfObject:@"com.apple.mediaremote.controlcenter.audio"];
		if(audioIndex != NSNotFound)
		{
			[defaultUserEnabledModuleIdentifiers insertObject:@"com.apple.FocusUIModule" atIndex:audioIndex+1];
		}
	}

	return defaultUserEnabledModuleIdentifiers;
}

//Disable stock home controls
- (NSArray*)orderedUserEnabledFixedModuleIdentifiers
{
	return @[];
}

// Problem: On iOS 15, this method removes the Focus module from _orderedUserEnabledModuleIdentifiers
// Additionally this also removes the "Do Not Disturb" and "Do Not Disturb While Driving" modules, these are hidden on stock iOS 15
// but as they exist and work on iOS 15 just fine and are automatically unhidden by CCSupport anyways, I decided to leave them in
- (void)_queue_loadSettings
{
	NSLog(@"loadSettings begin");
	// This is kinda hacky but there is no better way of archiving this due to how the method functions, see NSMutableArray hook above
	g_mutableArrayPreventRemoval = @[@"com.apple.FocusUIModule", @"com.apple.donotdisturb.DoNotDisturbModule", @"com.apple.control-center.CarModeModule"];
	%orig;
	g_mutableArrayPreventRemoval = nil;
	NSLog(@"loadSettings end");
}

%end
%end

%group ControlCenterUI
%hook CCUIModuleInstanceManager

%new
- (CCUIModuleInstance*)instanceForModuleIdentifier:(NSString*)moduleIdentifier
{
	NSMutableDictionary* moduleInstanceByIdentifier = MSHookIvar<NSMutableDictionary*>(self, "_moduleInstanceByIdentifier");

	return [moduleInstanceByIdentifier objectForKey:moduleIdentifier];
}

//Get instances from module providers

- (id)_instantiateModuleWithMetadata:(CCSModuleMetadata*)metadata
{
	CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
	if([providerManager doesProvideModule:metadata.moduleIdentifier])
	{
		NSObject* module = [providerManager moduleInstanceForModuleIdentifier:metadata.moduleIdentifier];
		if([module respondsToSelector:@selector(setContentModuleContext:)])
		{
			NSObject<CCUIContentModule>* contentModule = (NSObject<CCUIContentModule>*)module;
			CCUIContentModuleContext* contentModuleContext = [[%c(CCUIContentModuleContext) alloc] initWithModuleIdentifier:metadata.moduleIdentifier];
			contentModuleContext.delegate = self;
			[contentModule setContentModuleContext:contentModuleContext];
		}

		if(module && [module conformsToProtocol:@protocol(CCUIContentModule)])
		{
			CCUILayoutSize prototypeModuleSize;
			prototypeModuleSize.width = 1;
			prototypeModuleSize.height = 1;

			CCUIModuleInstance* instance = [[%c(CCUIModuleInstance) alloc] initWithMetadata:metadata module:module prototypeModuleSize:prototypeModuleSize];

			return instance;
		}
		else
		{
			return nil;
		}		
	}
	else
	{
		return %orig;
	}
}

%end

%hook CCUIModuleSettings

%property(nonatomic, assign) BOOL ccs_usesDynamicSize;

%end

// 14.3 sizes re:
// -[CCUIModuleInstanceManager requestModuleLayoutSizeUpdateForContentModuleContext:]
// runs moduleInstancesLayoutChangedForModuleInstanceManager: on observers
// -[CCUIModuleCollectionViewController moduleInstancesLayoutChangedForModuleInstanceManager:]
// runs _updatePositionProviders -> _refreshPositionProviders -> _sizesForModuleIdentifiers:moduleInstanceByIdentifier:interfaceOrientation:
// in the end -[CCUIModuleCollectionViewController _sizesForModuleIdentifiers:moduleInstanceByIdentifier:interfaceOrientation:] is invoked
// which calls moduleLayoutSizeForOrientation: on the contentViewController of the module if it exists

%hook CCUIModuleCollectionViewController

- (NSArray<NSValue*>*)_sizesForModuleIdentifiers:(NSArray<NSString*>*)moduleIdentifiers moduleInstanceByIdentifier:(NSDictionary*)moduleInstanceByIdentifier interfaceOrientation:(long long)interfaceOrientation
{
	NSArray<NSValue*>* sizes = %orig;
	NSMutableArray* sizesM = nil;
	BOOL shouldReturnCopy = NO;

	CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
	CCUIModuleSettingsManager* settingsManager = [self valueForKey:@"_settingsManager"];

	int orientationForInterfaceOrientation;
	if(interfaceOrientation == 4)
	{
		orientationForInterfaceOrientation = CCOrientationLandscape;
	}
	else
	{
		orientationForInterfaceOrientation = CCOrientationPortrait;
	}

	for(NSString* moduleIdentifier in moduleIdentifiers)
	{
		CCUIModuleInstance* moduleInstance = [moduleInstanceByIdentifier objectForKey:moduleIdentifier];
		CCSModuleMetadata* metadata = moduleInstance.metadata;

		// protect against crashes if moduleBundleURL is nil
		if(!metadata.moduleBundleURL)
		{
			continue;
		}

		NSBundle* moduleBundle = [NSBundle bundleWithURL:metadata.moduleBundleURL];
		NSNumber* getSizeAtRuntime = [moduleBundle objectForInfoDictionaryKey:@"CCSGetModuleSizeAtRuntime"];

		NSValue* sizeToSet;
		BOOL ccs_usesDynamicSizeToSet = NO;

		if([getSizeAtRuntime boolValue] || [providerManager doesProvideModule:moduleIdentifier])
		{
			NSObject<DynamicSizeModule>* module = (NSObject<DynamicSizeModule>*)moduleInstance.module;

			if(module && [module respondsToSelector:@selector(moduleSizeForOrientation:)])
			{
				CCUILayoutSize layoutSize = [module moduleSizeForOrientation:orientationForInterfaceOrientation];
				ccs_usesDynamicSizeToSet = YES;
				sizeToSet = [NSValue ccui_valueWithLayoutSize:layoutSize];
			}
		}
		else
		{
			NSDictionary* moduleSizeDict = [moduleBundle objectForInfoDictionaryKey:@"CCSModuleSize"];
			NSDictionary* moduleSizeOrientationDict;

			if(orientationForInterfaceOrientation == CCOrientationPortrait)
			{
				moduleSizeOrientationDict = [moduleSizeDict objectForKey:@"Portrait"];
			}
			else if(orientationForInterfaceOrientation == CCOrientationLandscape)
			{
				moduleSizeOrientationDict = [moduleSizeDict objectForKey:@"Landscape"];
			}

			if(moduleSizeOrientationDict)
			{
				NSNumber* widthNum = [moduleSizeOrientationDict objectForKey:@"Width"];
				NSNumber* heightNum = [moduleSizeOrientationDict objectForKey:@"Height"];

				if(widthNum && heightNum)
				{
					CCUILayoutSize layoutSize;
					layoutSize.width = [widthNum unsignedIntegerValue];
					layoutSize.height = [heightNum unsignedIntegerValue];
					sizeToSet = [NSValue ccui_valueWithLayoutSize:layoutSize];
				}
			}
		}

		// Makes it possible for third party tweaks to check which modules have dynamic sizes
		CCUIModuleSettings* moduleSettings = [settingsManager moduleSettingsForModuleIdentifier:moduleIdentifier prototypeSize:moduleInstance.prototypeModuleSize];
		moduleSettings.ccs_usesDynamicSize = ccs_usesDynamicSizeToSet;

		if(sizeToSet)
		{
			if(!sizesM)
			{
				//on iOS 12 and below, sizes is not mutable
				if([sizes respondsToSelector:@selector(addObject:)])
				{
					sizesM = (NSMutableArray*)sizes;
				}
				else
				{
					shouldReturnCopy = YES;
					sizesM = [sizes mutableCopy];
				}
			}

			NSInteger index = [moduleIdentifiers indexOfObject:moduleIdentifier];
			[sizesM replaceObjectAtIndex:index withObject:sizeToSet];
		}
	}

	if(!sizesM)
	{
		return sizes;
	}

	if(shouldReturnCopy)
	{
		return [sizesM copy];
	}

	return sizesM;
}

%end
%end

%group ControlCenterSettings_SortingFix_iOS13Down

%hook CCUISettingsModulesController

//By default there is a bug in iOS 11-13 where this method sorts the identifiers differently than _repoplateModuleData
//We fix this by sorting it in the same way
//_repoplateModuleData sorts with localizedStandardCompare:
//this method normally sorts with compare:
- (NSUInteger)_indexForInsertingItemWithIdentifier:(NSString*)identifier intoArray:(NSArray*)array
{
	return [array indexOfObject:identifier inSortedRange:NSMakeRange(0, array.count) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id identifier1, id identifier2)
	{
		CCUISettingsModuleDescription* identifier1Description = [self _descriptionForIdentifier:identifier1];
		CCUISettingsModuleDescription* identifier2Description = [self _descriptionForIdentifier:identifier2];

		return [identifier1Description.displayName localizedStandardCompare:identifier2Description.displayName];
	}];
}

%end

%end

%group ControlCenterSettings_Shared

#define eccSelf ((UIViewController<SettingsControllerSharedAcrossVersions>*)self)

%hook CCUISettingsModuleDescription

- (instancetype)initWithIdentifier:(NSString*)identifier displayName:(NSString*)displayName iconImage:(UIImage*)icon
{
	CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
	if([providerManager doesProvideModule:identifier])
	{
		UIImage* providedIconImage = icon;
		NSString* providedDisplayName = [providerManager displayNameForModuleIdentifier:identifier];
		UIImage* moduleIcon = [providerManager settingsIconForModuleIdentifier:identifier];
		if(moduleIcon)
		{
			providedIconImage = moduleIconForImage(moduleIcon);
		}

		return %orig(identifier, providedDisplayName, providedIconImage);
	}

	return %orig;
}

%end

%hook SettingsControllerSharedAcrossVersions //iOS >=11

%property (nonatomic, retain) NSDictionary* ccsp_additionalModuleIcons;

%property (nonatomic, retain) NSDictionary *preferenceClassForModuleIdentifiers;

//Load icons for normally fixed modules and determine which modules have preferences
- (void)_repopulateModuleData
{
	if(!eccSelf.ccsp_additionalModuleIcons)
	{
		NSMutableDictionary* ccsp_additionalModuleIcons = [NSMutableDictionary new];

		for(NSString* moduleIdentifier in fixedModuleIdentifiers)
		{
			NSString* imageIdentifier = moduleIdentifier;

			if([imageIdentifier isEqualToString:@"com.apple.donotdisturb.DoNotDisturbModule"]) //Fix DND icon on 12 and above
			{
				imageIdentifier = @"com.apple.control-center.DoNotDisturbModule";
			}
			else if([imageIdentifier isEqualToString:@"com.apple.mediaremote.controlcenter.audio"]) //Fix Volume Icon on 13 and above
			{
				imageIdentifier = @"com.apple.control-center.AudioModule";
			}

			UIImage* moduleIcon = [UIImage imageNamed:imageIdentifier inBundle:CCSupportBundle compatibleWithTraitCollection:nil];
			
			if(moduleIcon)
			{
				[ccsp_additionalModuleIcons setObject:moduleIcon forKey:moduleIdentifier];
			}
		}

		if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0)
		{
			UIImage* moduleIcon = [UIImage imageNamed:@"com.apple.FocusUIModule" inBundle:CCSupportBundle compatibleWithTraitCollection:nil];
			[ccsp_additionalModuleIcons setObject:moduleIcon forKey:@"com.apple.FocusUIModule"];
		}

		eccSelf.ccsp_additionalModuleIcons = [ccsp_additionalModuleIcons copy];
	}

	%orig;

	NSMutableArray* enabledIdentfiers = MSHookIvar<NSMutableArray*>(self, "_enabledIdentifiers");
	NSMutableArray* disabledIdentifiers = MSHookIvar<NSMutableArray*>(self, "_disabledIdentifiers");
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_15_0)
	{
		// remove useless module that's normally hidden because of whitelist on iOS 15
		[enabledIdentfiers removeObject:@"com.apple.TelephonyUtilities.SilenceCallsCCWidget"];
		[disabledIdentifiers removeObject:@"com.apple.TelephonyUtilities.SilenceCallsCCWidget"];
	}

	NSArray* moduleIdentifiers = [enabledIdentfiers arrayByAddingObjectsFromArray:disabledIdentifiers];

	NSMutableDictionary* preferenceClassForModuleIdentifiersM = [NSMutableDictionary new];

	for(NSString* moduleIdentifier in moduleIdentifiers)
	{
		CCSModuleRepository* moduleRepository = MSHookIvar<CCSModuleRepository*>(self, "_moduleRepository");

		NSURL* bundleURL = [moduleRepository moduleMetadataForModuleIdentifier:moduleIdentifier].moduleBundleURL;

		NSBundle* bundle = [NSBundle bundleWithURL:bundleURL];

		NSString* rootListControllerClassName = [bundle objectForInfoDictionaryKey:@"CCSPreferencesRootListController"];

		CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
		if([providerManager providesListControllerForModuleIdentifier:moduleIdentifier])
		{
			rootListControllerClassName = @"CCSProvidedListController";
		}

		if(rootListControllerClassName)
		{
			[preferenceClassForModuleIdentifiersM setObject:rootListControllerClassName forKey:moduleIdentifier];
		}
	}

	eccSelf.preferenceClassForModuleIdentifiers = [preferenceClassForModuleIdentifiersM copy];
}

//Add localized names & icons
- (CCUISettingsModuleDescription*)_descriptionForIdentifier:(NSString*)identifier
{
	CCUISettingsModuleDescription* moduleDescription = %orig;

	if([fixedModuleIdentifiers containsObject:identifier] || [identifier isEqualToString:@"com.apple.FocusUIModule"])
	{
		MSHookIvar<NSString*>(moduleDescription, "_displayName") = localize(moduleDescription.displayName);
	}

	if([eccSelf.ccsp_additionalModuleIcons.allKeys containsObject:identifier])
	{
		MSHookIvar<UIImage*>(moduleDescription, "_iconImage") = moduleIconForImage([eccSelf.ccsp_additionalModuleIcons objectForKey:identifier]);
	}

	return moduleDescription;
}

%new
- (UITableView*)ccs_getTableView
{
	if(obj_hasIvar(self, "_table")) //iOS >=14
	{
		return MSHookIvar<UITableView*>(self, "_table");
	}
	else if(obj_hasIvar(self, "_tableViewController")) //iOS 11-13
	{
		UITableViewController* tableViewController = MSHookIvar<UITableViewController*>(self, "_tableViewController");
		return tableViewController.tableView;
	}

	return nil;
}

%new
- (void)ccs_unselectSelectedRow
{
	UITableView* tableView = [self ccs_getTableView];

	NSIndexPath* selectedRow = [tableView indexPathForSelectedRow];

	if(selectedRow)
	{
		[tableView deselectRowAtIndexPath:selectedRow animated:YES];
	}
}

%new
- (void)ccs_resetButtonPressed
{
	UITableView* tableView = [eccSelf ccs_getTableView];

	UIAlertController* resetAlert = [UIAlertController alertControllerWithTitle:localize(@"RESET_MODULES") message:localize(@"RESET_MODULES_DESCRIPTION") preferredStyle:UIAlertControllerStyleAlert];

	[resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_DEFAULT_CONFIGURATION") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
	{
		[[NSFileManager defaultManager] removeItemAtPath:DefaultModuleConfigurationPath error:nil];
		[self ccs_unselectSelectedRow];
	}]];

	[resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_CCSUPPORT_CONFIGURATION") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
	{
		[[NSFileManager defaultManager] removeItemAtPath:CCSupportModuleConfigurationPath error:nil];

		//Reload CCSupport configuration
		[eccSelf _repopulateModuleData];
		[tableView reloadData];

		[self ccs_unselectSelectedRow];
	}]];

	[resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_BOTH_CONFIGURATIONS") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
	{
		[[NSFileManager defaultManager] removeItemAtPath:DefaultModuleConfigurationPath error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:CCSupportModuleConfigurationPath error:nil];

		//Reload CCSupport configuration
		[eccSelf _repopulateModuleData];
		[tableView reloadData];

		[self ccs_unselectSelectedRow];
	}]];

	[resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
	{
		[self ccs_unselectSelectedRow];
	}]];

	[eccSelf presentViewController:resetAlert animated:YES completion:nil];
}

%end
%end

%group ControlCenterSettings_ModulesController

%hook CCUISettingsModulesController //iOS 11-13

//Unselect module
- (void)viewDidAppear:(BOOL)animated
{
	%orig;

	[self ccs_unselectSelectedRow];
}

//Add section for reset button to table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	tableView.allowsSelectionDuringEditing = YES;
	return %orig + 1;
}

//Set rows of new section to 1
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if(section == 2)
	{
		return 1;
	}
	else
	{
		return %orig;
	}
}

//Add reset button to new section and add an arrow to modules with preferences
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 2)
	{
		//Create cell for reset button
		UITableViewCell* resetCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ResetCell"];

		resetCell.textLabel.text = localize(@"RESET_MODULES");
		resetCell.textLabel.textColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];

		return resetCell;
	}
	else
	{
		UITableViewCell* cell = %orig;

		NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];

		if([self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
		{
			cell.selectionStyle = UITableViewCellSelectionStyleDefault;
			cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		else
		{
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.editingAccessoryType = UITableViewCellAccessoryNone;
		}

		return cell;
	}
}

//Present alert to reset CC configuration on button click or push preferences controller if the pressed module has preferences
%new
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 2 && indexPath.row == 0)
	{
		[self ccs_resetButtonPressed];
	}
	else
	{
		NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];
		NSString* rootListControllerClassName = [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier];

		if(rootListControllerClassName)
		{
			if([rootListControllerClassName isEqualToString:@"CCSProvidedListController"])
			{
				CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
				PSListController* listController = [providerManager listControllerForModuleIdentifier:moduleIdentifier];
				[self.navigationController pushViewController:listController animated:YES];
			}
			else
			{
				CCSModuleRepository* moduleRepository = MSHookIvar<CCSModuleRepository*>(self, "_moduleRepository");
				NSBundle* moduleBundle = [NSBundle bundleWithURL:[moduleRepository moduleMetadataForModuleIdentifier:moduleIdentifier].moduleBundleURL];

				Class rootListControllerClass = NSClassFromString(rootListControllerClassName);

				if(!rootListControllerClass)
				{
					[moduleBundle load];
					rootListControllerClass = NSClassFromString(rootListControllerClassName);
				}

				if(rootListControllerClass)
				{
					PSListController* listController = [[rootListControllerClass alloc] init];
					[self.navigationController pushViewController:listController animated:YES];
				}
			}
		}
	}
}

//Make everything except reset button and modules with preferences not clickable
%new
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];

	if(indexPath.section == 2 || [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
	{
		return indexPath;
	}
	else
	{
		return nil;
	}
}

//Make reset button not movable
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 2)
	{
		return NO;
	}
	else
	{
		return %orig;
	}
}

//Make reset button not editable
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 2)
	{
		return NO;
	}
	else
	{
		return %orig;
	}
}

%end
%end

%group ControlCenterSettings_ListController
%hook CCUISettingsListController

- (void)viewDidLoad
{
	%orig;
	UITableView* tableView = [self ccs_getTableView];
	tableView.allowsSelectionDuringEditing = YES;
}

- (NSMutableArray*)specifiers
{
	BOOL startingFresh = [self valueForKey:@"_specifiers"] == nil;

	NSMutableArray* specifiers = %orig;

	if(startingFresh)
	{
		PSSpecifier* resetButtonGroupSpecifier = [PSSpecifier emptyGroupSpecifier];

		PSSpecifier* resetButtonSpecifier = [PSSpecifier preferenceSpecifierNamed:localize(@"RESET_MODULES")
                                                target:self
                                                set:nil
                                                get:nil
                                                detail:nil
                                                cell:PSButtonCell
                                                edit:nil];
        
        [resetButtonSpecifier setProperty:@YES forKey:@"enabled"];
        resetButtonSpecifier.buttonAction = @selector(ccs_resetButtonPressed);

		[specifiers addObject:resetButtonGroupSpecifier];
		[specifiers addObject:resetButtonSpecifier];

		for(PSSpecifier* specifier in [specifiers reverseObjectEnumerator])
		{
			if([specifier.identifier isEqualToString:@"SHOW_HOME_CONTROLS"])
			{
				[specifier setProperty:@NO forKey:@"enabled"];
			}
			else if([specifier.identifier isEqualToString:@"SHOW_HOME_CONTROLS_GROUP"])
			{
				[specifier setProperty:localize(@"HOME_CONTROLS_NOTICE") forKey:@"footerText"];
			}
		}
	}

	return specifiers;
}

- (id)controllerForSpecifier:(PSSpecifier*)specifier
{
	NSString* detail = NSStringFromClass(specifier.detailControllerClass);

	if([detail isEqualToString:@"CCSProvidedListController"])
	{
		NSIndexPath* indexPath = [self indexPathForSpecifier:specifier];
		NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];

		CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
		return [providerManager listControllerForModuleIdentifier:moduleIdentifier];
	}

	return %orig;
}

- (NSMutableArray*)_specifiersForIdentifiers:(NSArray*)identifiers
{
	NSMutableArray* specifiers = %orig;
	NSUInteger identifiersCount = identifiers.count;

	for(PSSpecifier* specifier in specifiers)
	{
		NSInteger index = [specifiers indexOfObject:specifier];
		if(index >= identifiersCount)
		{
			break;
		}

		NSString* moduleIdentifier = [identifiers objectAtIndex:index];

		if([fixedModuleIdentifiers containsObject:moduleIdentifier] || [moduleIdentifier isEqualToString:@"com.apple.FocusUIModule"])
		{
			specifier.name = localize(specifier.name);
		}
		CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
		if([providerManager doesProvideModule:moduleIdentifier])
		{
			specifier.name = [providerManager displayNameForModuleIdentifier:moduleIdentifier];
		}

		NSString* rootListControllerClassName = [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier];

		if(rootListControllerClassName)
		{
			Class rootListControllerClass = NSClassFromString(rootListControllerClassName);

			if(!rootListControllerClass)
			{
				CCSModuleRepository* moduleRepository = MSHookIvar<CCSModuleRepository*>(self, "_moduleRepository");
				NSBundle* moduleBundle = [NSBundle bundleWithURL:[moduleRepository moduleMetadataForModuleIdentifier:moduleIdentifier].moduleBundleURL];
				[moduleBundle load];
				rootListControllerClass = NSClassFromString(rootListControllerClassName);
			}

			if(rootListControllerClass)
			{
				specifier.cellType = PSLinkListCell;
				specifier.detailControllerClass = rootListControllerClass;
			}
		}
	}

	return specifiers;
}

//Make reset button and modules with preference pages clickable
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];
	NSInteger numberOfSections = [self numberOfSectionsInTableView:tableView];

	if(indexPath.section == numberOfSections-1 || [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
	{
		return indexPath;
	}
	else
	{
		return nil;
	}
}

%new
- (NSIndexPath *)tableView:(UITableView*)tableView willSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];
	NSInteger numberOfSections = [self numberOfSectionsInTableView:tableView];

	if(indexPath.section == numberOfSections-1 || [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
	{
		return indexPath;
	}
	else
	{
		return nil;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell* cell = %orig;
	NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];
	
	if([self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
	{
		cell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	else
	{
		cell.editingAccessoryType = UITableViewCellAccessoryNone;
	}

	return cell;
}


%end

%end

%group safetyChecksFailed
%hook SBHomeScreenViewController

BOOL safetyAlertPresented = NO;

- (void)viewDidAppear:(BOOL)arg1
{
	%orig;

	//To prevent a safe mode crash (or worse things???) we error out because system files were modified by the user
	if(!safetyAlertPresented)
	{
		UIAlertController* safetyAlert = [UIAlertController alertControllerWithTitle:localize(@"SAFETY_TITLE") message:localize(@"SAFETY_MESSAGE") preferredStyle:UIAlertControllerStyleAlert];

		[safetyAlert addAction:[UIAlertAction actionWithTitle:localize(@"SAFETY_BUTTON_CLOSE") style:UIAlertActionStyleDefault handler:nil]];
		[safetyAlert addAction:[UIAlertAction actionWithTitle:localize(@"SAFETY_BUTTON_OPEN") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/r/jailbreak/comments/8k6v88/release_cccleaner_a_tool_to_restore_previously/"] options:@{} completionHandler:nil];
		}]];

		[self presentViewController:safetyAlert animated:YES completion:nil];

		safetyAlertPresented = YES;
	}
}

%end
%end

void reloadModuleSizes(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[%c(CCUIModularControlCenterViewController) _sharedCollectionViewController] _refreshPositionProviders];
}

void reloadModuleProviders(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	CCSModuleProviderManager* providerManager = [CCSModuleProviderManager sharedInstance];
	[providerManager reload];

	CCSModuleRepository* repository = [[%c(CCUIModuleInstanceManager) sharedInstance] valueForKey:@"_repository"];
	if([repository respondsToSelector:@selector(_updateAllModuleMetadata)])
	{
		[repository _updateAllModuleMetadata];
	}
	else
	{
		NSObject<OS_dispatch_queue>* queue = [repository valueForKey:@"_queue"];
		if(queue)
		{
			dispatch_async(queue, ^
			{
				[repository _queue_updateAllModuleMetadata];
			});
		}
	}	
}

void initControlCenterUIHooks()
{
	%init(ControlCenterUI);
}

void initControlCenterServicesHooks()
{
	if(!isSpringBoard)
	{
		if(loadFixedModuleIdentifiers())
		{
			return;
		}
	}
	%init(ControlCenterServices);
}

void initControlCenterSettingsHooks()
{
	if(!isSpringBoard)
	{
		if(loadFixedModuleIdentifiers())
		{
			return;
		}
	}

	Class settingsControllerClass;

	Class settingsControllerClass_14Up = NSClassFromString(@"CCUISettingsListController");
	Class settingsControllerClass_13Down = NSClassFromString(@"CCUISettingsModulesController");

	if(settingsControllerClass_14Up && !settingsControllerClass_13Down)
	{
		settingsControllerClass = settingsControllerClass_14Up;
		%init(ControlCenterSettings_ListController);
	}
	else if(settingsControllerClass_13Down)
	{
		%init(ControlCenterSettings_SortingFix_iOS13Down);
		
		settingsControllerClass = settingsControllerClass_13Down;
		%init(ControlCenterSettings_ModulesController);
	}

	%init(ControlCenterSettings_Shared, SettingsControllerSharedAcrossVersions=settingsControllerClass);
}

static void bundleLoaded(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSBundle* bundle = (__bridge NSBundle*)(object);

	if([bundle.bundleIdentifier isEqualToString:@"com.apple.ControlCenterServices"])
	{
		initControlCenterServicesHooks();
	}
	else if([bundle.bundleIdentifier isEqualToString:@"com.apple.ControlCenterSettings"])
	{
		initControlCenterSettingsHooks();
	}
}

%ctor
{
	CCSupportBundle = [NSBundle bundleWithPath:CCSupportBundlePath];
	isSpringBoard = [[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"];

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, reloadModuleProviders, CFSTR("com.opa334.ccsupport/ReloadProviders"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

	if(isSpringBoard)
	{
		if(!loadFixedModuleIdentifiers())
		{
			initControlCenterUIHooks();
			initControlCenterServicesHooks();

			//Notification to reload sizes without respring
			CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, reloadModuleSizes, CFSTR("com.opa334.ccsupport/ReloadSizes"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
		}
		else	//Safety checks failed
		{
			%init(safetyChecksFailed);
		}
	}
	else
	{
		//Credits to Silo for this: https://github.com/ioscreatix/Silo/blob/master/Tweak.xm
		//Register for bundle load notification, this allows us to initialize hooks for classes that are loaded from bundles at runtime
		CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, bundleLoaded, (CFStringRef)NSBundleDidLoadNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
}
