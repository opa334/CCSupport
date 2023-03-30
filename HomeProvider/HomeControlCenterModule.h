#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Home.h"

@protocol HFItemManagerDelegate;

@protocol HUCCMosaicLayoutDelegate
@required
-(void)itemManagerDidChangeMosaicLayout:(id)arg1;
@end

@interface HUCCControlCenterModule : NSObject
- (instancetype)init;
@end

@interface HUCCSmartGridContentViewController : UIViewController
-(id)initWithDelegate:(id)arg1;
@end

@interface HUCCSmartGridItemManager : HFItemManager
@property (nonatomic,retain) id homeItemProvider;
@property (nonatomic,retain) id predictionsItemProvider;
@property (assign,nonatomic) id<HUCCMosaicLayoutDelegate> mosaicLayoutDelegate;
@property (nonatomic,retain) NSMutableDictionary * mosaicLayoutDetails;
@property (assign,nonatomic) unsigned long long chosenLayoutType;
@property (assign,nonatomic) BOOL layoutWasChanged;
- (id)initWithMosaicLayoutDelegate:(id<HUCCMosaicLayoutDelegate>)arg1;
-(void)loadDefaultProviderItem;
@end

@interface HUCCMosaicArranger : NSObject
-(id)initWithCCMosaicType:(unsigned long long)arg1 ;
@end

@interface HUCCSmartGridLayout : NSObject
+(unsigned long long)mosaicType;
@end

@interface HUCCSmartGridViewController : UIViewController
@property (nonatomic,readonly) HUCCSmartGridItemManager * itemManager;
-(id)initWithItemType:(unsigned long long)arg1 delegate:(id)arg2 ;
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)a;
@end