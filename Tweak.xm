#import "CCSupport.h"
#import "Defines.h"

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NSArray* fixedModuleIdentifiers;//Identifiers of (normally) fixed modules
NSBundle* CCSupportBundle;	//Bundle for icons and localization (only needed / initialized in settings)
NSDictionary* englishLocalizations;	//English localizations for fallback
BOOL isSpringBoard;	//Are we SpringBoard???

//Get localized string for given key
NSString* localize(NSString* key)
{
	if([key isEqualToString:@"MediaControlsAudioModule"]) //Fix Volume name on 13 and above
	{
		key = @"AudioModule";
	}
	
	NSString* localizedString = [CCSupportBundle localizedStringForKey:key value:@"" table:nil];

	if([localizedString isEqualToString:@""])
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

//Get fixed module identifiers from device specific plist (Return value: whether the plist was modified or not)
BOOL loadFixedModuleIdentifiers()
{
	static dispatch_once_t onceToken;
	dispatch_once (&onceToken,
	^{
		//This method is called before the hook of it is initialized, that's why we can get the actual fixed identifiers here
		fixedModuleIdentifiers = [%c(CCSModuleSettingsProvider) _defaultFixedModuleIdentifiers];
	});

	//If this array contains less than 7 objects, something was modified with no doubt
	return ([fixedModuleIdentifiers count] < 7);
}

%group ControlCenterServices
%hook CCSModuleRepository

//Add path for third party bundles to directory urls
+ (NSArray<NSURL*>*)_defaultModuleDirectories
{
	NSArray<NSURL*>* directories = %orig;

	if(directories)
	{
    #ifdef ROOTLESS
		NSURL* thirdPartyURL = [NSURL fileURLWithPath:[[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System/Library" withString:@"/var/LIB"] isDirectory:YES];
    #else
		NSURL* thirdPartyURL = [NSURL fileURLWithPath:[[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System" withString:@""] isDirectory:YES];
    #endif

		return [directories arrayByAddingObject:thirdPartyURL];
	}

	return directories;
}

//Enable non whitelisted modules to be loaded

- (void)_queue_updateAllModuleMetadata	//iOS 12 up
{
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_14_0)
	{
		MSHookIvar<BOOL>(self, "_ignoreAllowedList") = YES;
	}
	else
	{
		MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
	}

	
	%orig;
}

- (void)_updateAllModuleMetadata //iOS 11
{
	if(kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_12_0)
	{
		MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
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
	return [NSMutableArray array];
}

//Return fixed + non fixed modules
+ (NSMutableArray*)_defaultUserEnabledModuleIdentifiers
{
	return [[fixedModuleIdentifiers arrayByAddingObjectsFromArray:%orig] mutableCopy];
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

%end

%hook CCUIModuleSettingsManager

//Load custom sizes from plist / from method
- (CCUIModuleSettings*)moduleSettingsForModuleIdentifier:(NSString*)moduleIdentifier prototypeSize:(CCUILayoutSize)arg2
{
	CCUIModuleSettings* moduleSettings = %orig;

	CCUIModuleInstance* moduleInstance = [[%c(CCUIModuleInstanceManager) sharedInstance] instanceForModuleIdentifier:moduleIdentifier];
	NSObject<DynamicSizeModule>* module = (NSObject<DynamicSizeModule>*)moduleInstance.module;

	NSBundle* moduleBundle = [NSBundle bundleWithURL:moduleInstance.metadata.moduleBundleURL];
	NSNumber* getSizeAtRuntime = [moduleBundle objectForInfoDictionaryKey:@"CCSGetModuleSizeAtRuntime"];

	if([getSizeAtRuntime boolValue])
	{
		if([module respondsToSelector:@selector(moduleSizeForOrientation:)])
		{
			MSHookIvar<CCUILayoutSize>(moduleSettings, "_portraitLayoutSize") = [module moduleSizeForOrientation:CCOrientationPortrait];
			MSHookIvar<CCUILayoutSize>(moduleSettings, "_landscapeLayoutSize") = [module moduleSizeForOrientation:CCOrientationLandscape];
		}
	}
	else
	{
		NSDictionary* moduleSizeDict = [moduleBundle objectForInfoDictionaryKey:@"CCSModuleSize"];

		if(moduleSizeDict)
		{
			NSDictionary* moduleSizePortraitDict = [moduleSizeDict objectForKey:@"Portrait"];
			NSDictionary* moduleSizeLandscapeDict = [moduleSizeDict objectForKey:@"Landscape"];

			if(moduleSizePortraitDict && moduleSizeLandscapeDict)
			{
				NSNumber* portraitWidth = [moduleSizePortraitDict objectForKey:@"Width"];
				NSNumber* portraitHeight = [moduleSizePortraitDict objectForKey:@"Height"];
				NSNumber* landscapeWidth = [moduleSizeLandscapeDict objectForKey:@"Width"];
				NSNumber* landscapeHeight = [moduleSizeLandscapeDict objectForKey:@"Height"];

				if(portraitWidth && portraitHeight && landscapeWidth && landscapeHeight)
				{
					CCUILayoutSize moduleSizePortrait, moduleSizeLandscape;

					moduleSizePortrait.width = [portraitWidth unsignedIntegerValue];
					moduleSizePortrait.height = [portraitHeight unsignedIntegerValue];
					moduleSizeLandscape.width = [landscapeWidth unsignedIntegerValue];
					moduleSizeLandscape.height = [landscapeHeight unsignedIntegerValue];

					MSHookIvar<CCUILayoutSize>(moduleSettings, "_portraitLayoutSize") = moduleSizePortrait;
					MSHookIvar<CCUILayoutSize>(moduleSettings, "_landscapeLayoutSize") = moduleSizeLandscape;
				}
			}
		}
	}

	return moduleSettings;
}

%end
%end

%group ControlCenterSettings_Shared

#define eccSelf ((UIViewController<SettingsControllerSharedAcrossVersions>*)self)

%hook SettingsControllerSharedAcrossVersions //iOS 11-14

%property (nonatomic, retain) NSDictionary *fixedModuleIcons;
%property (nonatomic, retain) NSDictionary *preferenceClassForModuleIdentifiers;

//Load icons for normally fixed modules and determine which modules have preferences
- (void)_repopulateModuleData
{
	if(!eccSelf.fixedModuleIcons)
	{
		NSMutableDictionary* fixedModuleIcons = [NSMutableDictionary new];

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
				[fixedModuleIcons setObject:moduleIcon forKey:moduleIdentifier];
			}
		}

		eccSelf.fixedModuleIcons = [fixedModuleIcons copy];
	}

	%orig;

	NSMutableArray* enabledIdentfiers = MSHookIvar<NSMutableArray*>(self, "_enabledIdentifiers");
	NSMutableArray* disabledIdentifiers = MSHookIvar<NSMutableArray*>(self, "_disabledIdentifiers");

	NSArray* moduleIdentfiers = [enabledIdentfiers arrayByAddingObjectsFromArray:disabledIdentifiers];

	NSMutableDictionary* preferenceClassForModuleIdentifiersM = [NSMutableDictionary new];

	for(NSString* moduleIdentifier in moduleIdentfiers)
	{
		CCSModuleRepository* moduleRepository = MSHookIvar<CCSModuleRepository*>(self, "_moduleRepository");

		NSURL* bundleURL = [moduleRepository moduleMetadataForModuleIdentifier:moduleIdentifier].moduleBundleURL;

		NSBundle* bundle = [NSBundle bundleWithURL:bundleURL];

		NSString* rootListControllerClassName = [bundle objectForInfoDictionaryKey:@"CCSPreferencesRootListController"];

		if(rootListControllerClassName)
		{
			[preferenceClassForModuleIdentifiersM setObject:rootListControllerClassName forKey:moduleIdentifier];
		}
	}

	eccSelf.preferenceClassForModuleIdentifiers = [preferenceClassForModuleIdentifiersM copy];
}

//Replace blank icons with icons loaded above
- (UIImage*)_iconForBundle:(NSBundle*)bundle
{
	UIImage* fixedModuleIcon = [eccSelf.fixedModuleIcons objectForKey:bundle.bundleIdentifier];
	if(fixedModuleIcon)
	{
		//Mimic how the original implementation creates the icon
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

		CGImageRef image = LICreateIconForImage([fixedModuleIcon CGImage], imageVariant, 0);

		return [[UIImage alloc] initWithCGImage:image scale:screenScale orientation:0];
	}

	return %orig;
}

//Add localized names
- (CCUISettingsModuleDescription*)_descriptionForIdentifier:(NSString*)identifier
{
	CCUISettingsModuleDescription* moduleDescription = %orig;

	if([fixedModuleIdentifiers containsObject:identifier])
	{
		MSHookIvar<NSString*>(moduleDescription, "_displayName") = localize(moduleDescription.displayName);
	}

	return moduleDescription;
}

%new
- (UITableView*)ccs_getTableView
{
	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_14_0)
	{
		return MSHookIvar<UITableView*>(self, "_table");
	}
	else
	{
		UITableViewController* tableViewController = MSHookIvar<UITableViewController*>(self, "_tableViewController");
		return tableViewController.tableView;
	}
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

- (NSMutableArray*)specifiers
{
	BOOL startingFresh = [self valueForKey:@"_specifiers"] == nil;

	NSMutableArray* specifiers = %orig;

	if(startingFresh)
	{
		PSSpecifier* resetButtonGroupSpecifier = [PSSpecifier emptyGroupSpecifier];
        [resetButtonGroupSpecifier setProperty:localize(@"RESET_MODULES_DESCRIPTION") forKey:@"footerText"];

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
	}

	return specifiers;
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
			NSLog(@"shouldn't happen but better safe than sorry");
			break;
		}

		NSString* moduleIdentifier = [identifiers objectAtIndex:index];

		if([fixedModuleIdentifiers containsObject:moduleIdentifier])
		{
			specifier.name = localize(specifier.name);
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

				[specifier setProperty:NSStringFromClass(rootListControllerClass) forKey:@"detail"];
				[specifier setProperty:@YES forKey:@"enabled"];
				[specifier setProperty:@YES forKey:@"isController"];

				/*PSSpecifier* newSpecifier = [PSSpecifier preferenceSpecifierNamed:specifier.name
						  target:self
						  set:nil
						  get:nil
						  detail:rootListControllerClass
						  cell:PSLinkListCell
						  edit:nil];
				
				[newSpecifier setProperty:@YES forKey:@"enabled"];
				newSpecifier.detailControllerClass = rootListControllerClass;

				[specifiers replaceObjectAtIndex:index withObject:newSpecifier];*/
			}
		}		
	}

	return specifiers;
}

//Make everything except reset button and modules with preference pages not clickable
%new
- (NSIndexPath *)tableView:(UITableView*)tableView willSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];

	if(/*indexPath.section == 2 || */[self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier])
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	tableView.allowsSelectionDuringEditing = YES;
	[tableView setEditing:NO animated:NO];
	return %orig;
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

	if(kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_14_0)
	{
		settingsControllerClass = NSClassFromString(@"CCUISettingsListController");
		%init(ControlCenterSettings_ListController);
	}
	else
	{
		settingsControllerClass = NSClassFromString(@"CCUISettingsModulesController");
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
