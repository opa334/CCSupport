#import "CCSHPPreferencesListController.h"

#import <Preferences/PSSpecifier.h>

extern NSBundle *CCSupportBundle;

@implementation CCSHPPreferencesListController

- (NSArray *)specifiers
{
	if(!_specifiers)
	{
		_specifiers = [self loadSpecifiersFromPlistName:@"HomeProviderPreferences" target:self];
		for(PSSpecifier *specifier in _specifiers)
		{
			NSString *label = specifier.properties[@"label"];
			specifier.name = [CCSupportBundle localizedStringForKey:label value:label table:nil];
		}
	}

	[(UINavigationItem *)self.navigationItem setTitle:[CCSupportBundle localizedStringForKey:@"Home Controls" value:@"Home Controls" table:nil]];

	return _specifiers;
}

@end