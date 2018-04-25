#import "CCSupport.h"
#import "Defines.h"

//Used to create stock looking icons (couldn't figure out how to properly link the framework)
CGImageRef (*LICreateIconForImage)(CGImageRef, int, int);

//Identifiers of (normally) fixed modules
NSArray* fixedModuleIdentifiers = @[ConnectivityModuleIdentifier, MediaControlsModuleIdentifier, DoNotDisturbModuleIdentifier, OrientationLockModuleIdentifier, AudioModuleIdentifier, DisplayModuleIdentifier, ScreenMirroringModuleIdentifier];

//Bundle for icons and localization (only needed / initialized in settings)
NSBundle* CCSupportBundle;

//Get localized string for given key
NSString* localize(NSString* key)
{
  NSString* localizedString = [CCSupportBundle localizedStringForKey:key value:@"" table:nil];

  if([localizedString isEqualToString:@""])
  {
    //Fallback to english
    NSDictionary* engDict = [[NSDictionary alloc] initWithContentsOfFile:[CCSupportBundle pathForResource:@"Localizable" ofType:@"strings" inDirectory:@"en.lproj"]];
    NSString* engString = [engDict objectForKey:key];
    if(engString)
    {
      localizedString = engString;
    }
  }

  return localizedString;
}

%group ModuleRepository
%hook CCSModuleRepository

//Add path for third party bundles to directory urls
+ (NSArray<NSURL*>*)_defaultModuleDirectories
{
  NSArray<NSURL*>* directories = %orig;
  NSURL* thirdPartyURL = [NSURL fileURLWithPath:[[directories.firstObject path] stringByReplacingOccurrencesOfString:@"/System" withString:@""] isDirectory:YES];
  return [directories arrayByAddingObject:thirdPartyURL];
}

//Enable non whitelisted modules to be loaded
- (void)_updateAllModuleMetadata
{
  MSHookIvar<BOOL>(self, "_ignoreWhitelist") = YES;
  %orig;
}

%end
%end

%group ModuleSettingsProvider

%hook CCSModuleSettingsProvider

//Return different configuration plist to not mess everything up when the tweak is not enabled
+ (NSURL*)_configurationFileURL
{
  return [NSURL fileURLWithPath:CCSupportModuleConfigurationPath];
}

//Return empty array for fixed modules
+ (NSArray*)_defaultFixedModuleIdentifiers
{
  return @[];
}

//Return fixed + non fixed modules
+ (NSArray*)_defaultUserEnabledModuleIdentifiers
{
  return [fixedModuleIdentifiers arrayByAddingObjectsFromArray:%orig];
}

%end
%end

%group ModulesController
%hook CCUISettingsModulesController

%property(nonatomic, retain) NSDictionary *fixedModuleIcons;

//Load icons for normally fixed modules
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

//Add reset button to new section
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

    //Make official cells not selectable
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
  }
}

//Present alert to reset CC configuration on button click
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
}

//Make everything except reset button not clickable
%new
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if(indexPath.section == 2)
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

void initModuleRepositoryHooks()
{
  %init(ModuleRepository);
}

void initModuleSettingsProviderHooks()
{
  %init(ModuleSettingsProvider);
}

void initModulesControllerHooks()
{
  %init(ModulesController);
}

//Credits to Silo: https://github.com/ioscreatix/Silo/blob/master/Tweak.xm
static void classesLoaded(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if([((__bridge NSDictionary *)userInfo)[NSLoadedClasses] containsObject:@"CCSModuleRepository"])
  {
		initModuleRepositoryHooks();
	}
  if([((__bridge NSDictionary *)userInfo)[NSLoadedClasses] containsObject:@"CCSModuleSettingsProvider"])
  {
		initModuleSettingsProviderHooks();
	}
  if([((__bridge NSDictionary *)userInfo)[NSLoadedClasses] containsObject:@"CCUISettingsModulesController"])
  {
		initModulesControllerHooks();
	}
}

%ctor
{
  NSString* bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  if([bundleIdentifier isEqualToString:@"com.apple.springboard"])
  {
    initModuleRepositoryHooks();
    initModuleSettingsProviderHooks();
  }
  else if([bundleIdentifier isEqualToString:@"com.apple.Preferences"])
  {
    CCSupportBundle = [NSBundle bundleWithPath:CCSupportBundlePath];
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, classesLoaded, (CFStringRef)NSBundleDidLoadNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
  }

  //Do not try this at home
  LICreateIconForImage = (CGImageRef (*)(CGImage*, int, int))MSFindSymbol(NULL, "_LICreateIconForImage");
}
