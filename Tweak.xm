#import "CCSupport.h"
#import "Defines.h"

#import <Preferences/PSListController.h>

//Identifiers of (normally) fixed modules
NSArray* fixedModuleIdentifiers;

//Bundle for icons and localization (only needed / initialized in settings)
NSBundle* CCSupportBundle;

//English localizations for fallback
NSDictionary* englishLocalizations;

//Get localized string for given key
NSString* localize(NSString* key)
{
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
  NSString* device = [[UIDevice.currentDevice.model componentsSeparatedByString:@" "].firstObject lowercaseString]; //will contain ipad, ipod or iphone
  NSString* plistPath = [NSString stringWithFormat:DefaultModuleOrderPath, device];
  NSDictionary* plist = [[NSDictionary alloc] initWithContentsOfFile:plistPath];

  fixedModuleIdentifiers = [plist objectForKey:@"fixed"];

  //If this array contains less than 7 objects, the plist was modified with no doubt
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
    NSURL* thirdPartyURL = [NSURL fileURLWithPath:[[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System" withString:@"/var/mobile"] isDirectory:YES];
    #else
    NSURL* thirdPartyURL = [NSURL fileURLWithPath:[[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System" withString:@""] isDirectory:YES];
    #endif

    return [directories arrayByAddingObject:thirdPartyURL];
  }

  return directories;
}

//Enable non whitelisted modules to be loaded
- (void)_updateAllModuleMetadata
{
  MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
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

  NSDictionary* infoPlist = [NSDictionary dictionaryWithContentsOfURL:[moduleInstance.metadata.moduleBundleURL URLByAppendingPathComponent:@"Info.plist"]];
  NSNumber* getSizeAtRuntime = [infoPlist objectForKey:@"CCSGetModuleSizeAtRuntime"];

  if([getSizeAtRuntime boolValue])
  {
    if([moduleInstance.module respondsToSelector:@selector(moduleSizeForOrientation:)])
    {
      MSHookIvar<CCUILayoutSize>(moduleSettings, "_portraitLayoutSize") = [moduleInstance.module moduleSizeForOrientation:CCOrientationPortrait];
      MSHookIvar<CCUILayoutSize>(moduleSettings, "_landscapeLayoutSize") = [moduleInstance.module moduleSizeForOrientation:CCOrientationLandscape];
    }
  }
  else
  {
    NSDictionary* moduleSizeDict = [infoPlist objectForKey:@"CCSModuleSize"];

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

          moduleSizePortrait.width = [portraitWidth unsignedLongLongValue];
          moduleSizePortrait.height = [portraitHeight unsignedLongLongValue];
          moduleSizeLandscape.width = [landscapeWidth unsignedLongLongValue];
          moduleSizeLandscape.height = [landscapeHeight unsignedLongLongValue];

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

%group ControlCenterSettings
%hook CCUISettingsModulesController

//Unselect module
- (void)viewDidAppear:(BOOL)animated
{
  %orig;

  UITableViewController* tableViewController = MSHookIvar<UITableViewController*>(self, "_tableViewController");

  NSIndexPath* selectedRow = [tableViewController.tableView indexPathForSelectedRow];

  if(selectedRow)
  {
    [tableViewController.tableView deselectRowAtIndexPath:selectedRow animated:YES];
  }
}

%property(nonatomic, retain) NSDictionary *fixedModuleIcons;
%property(nonatomic, retain) NSDictionary *preferenceClassForModuleIdentifiers;

//Load icons for normally fixed modules and determine which modules have preferences
- (void)_repopulateModuleData
{
  if(!self.fixedModuleIcons)
  {
    NSMutableDictionary* fixedModuleIcons = [NSMutableDictionary new];

    for(NSString* moduleIdentifier in fixedModuleIdentifiers)
    {
      UIImage* moduleIcon = [UIImage imageNamed:moduleIdentifier inBundle:CCSupportBundle compatibleWithTraitCollection:nil];
      if(moduleIcon)
      {
        [fixedModuleIcons setObject:moduleIcon forKey:moduleIdentifier];
      }
    }

    self.fixedModuleIcons = [fixedModuleIcons copy];
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

    NSDictionary* infoPlist = [NSDictionary dictionaryWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]];

    NSString* rootListControllerClassName = [infoPlist objectForKey:@"CCSPreferencesRootListController"];

    if(rootListControllerClassName)
    {
      [preferenceClassForModuleIdentifiersM setObject:rootListControllerClassName forKey:moduleIdentifier];
    }
  }

  self.preferenceClassForModuleIdentifiers = [preferenceClassForModuleIdentifiersM copy];
}

//Replace blank icons with icons loaded above
- (UIImage*)_iconForBundle:(NSBundle*)bundle
{
  UIImage* fixedModuleIcon = [self.fixedModuleIcons objectForKey:bundle.bundleIdentifier];
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
    UIAlertController* resetAlert = [UIAlertController alertControllerWithTitle:localize(@"RESET_MODULES") message:localize(@"RESET_MODULES_DESCRIPTION") preferredStyle:UIAlertControllerStyleAlert];

    [resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_DEFAULT_CONFIGURATION") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
    {
      [[NSFileManager defaultManager] removeItemAtPath:DefaultModuleConfigurationPath error:nil];
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }]];

    [resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_CCSUPPORT_CONFIGURATION") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
    {
      [[NSFileManager defaultManager] removeItemAtPath:CCSupportModuleConfigurationPath error:nil];

      //Reload CCSupport configuration
      [self _repopulateModuleData];
      [tableView reloadData];

      [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }]];

    [resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"RESET_BOTH_CONFIGURATIONS") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action)
    {
      [[NSFileManager defaultManager] removeItemAtPath:DefaultModuleConfigurationPath error:nil];
      [[NSFileManager defaultManager] removeItemAtPath:CCSupportModuleConfigurationPath error:nil];

      //Reload CCSupport configuration
      [self _repopulateModuleData];
      [tableView reloadData];

      [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }]];

    [resetAlert addAction:[UIAlertAction actionWithTitle:localize(@"CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action)
    {
      [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }]];

    [self presentViewController:resetAlert animated:YES completion:nil];
  }
  else
  {
    NSString* moduleIdentifier = [self _identifierAtIndexPath:indexPath];
    NSString* rootListControllerClassName = [self.preferenceClassForModuleIdentifiers objectForKey:moduleIdentifier];

    CCSModuleRepository* moduleRepository = MSHookIvar<CCSModuleRepository*>(self, "_moduleRepository");
    NSBundle* moduleBundle = [NSBundle bundleWithURL:[moduleRepository moduleMetadataForModuleIdentifier:moduleIdentifier].moduleBundleURL];

    [moduleBundle load];

    Class rootListControllerClass = NSClassFromString(rootListControllerClassName);

    if(rootListControllerClass)
    {
      PSListController* listController = [[rootListControllerClass alloc] init];
      [self.navigationController pushViewController:listController animated:YES];
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

void initControlCenterUIHooks()
{
  %init(ControlCenterUI);
}

void initControlCenterServicesHooks()
{
  %init(ControlCenterServices);
}

void initControlCenterSettingsHooks()
{
  %init(ControlCenterSettings);
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

void reloadModuleSizes(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
  [[%c(CCUIModularControlCenterViewController) _sharedCollectionViewController] _refreshPositionProviders];
}

%ctor
{
  CCSupportBundle = [NSBundle bundleWithPath:CCSupportBundlePath];
  NSString* bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;

  BOOL isSpringBoard = [bundleIdentifier isEqualToString:@"com.apple.springboard"];

  if(!loadFixedModuleIdentifiers())
  {
    if(isSpringBoard)
    {
      initControlCenterUIHooks();
      initControlCenterServicesHooks();

      //Notification to reload sizes without respring
      CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, reloadModuleSizes, CFSTR("com.opa334.ccsupport/ReloadSizes"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    else
    {
      //Credits to Silo for this: https://github.com/ioscreatix/Silo/blob/master/Tweak.xm
      //Register for bundle load notification, this allows us to initialize hooks for classes that are loaded from bundles at runtime
      CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, bundleLoaded, (CFStringRef)NSBundleDidLoadNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    }
  }
  else
  {
    if(isSpringBoard)
    {
      %init(safetyChecksFailed);
    }
  }
}
