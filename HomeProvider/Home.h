@protocol HFItemManagerDelegate;
@protocol HFHomeKitObject <NSObject>
@property(readonly, copy, nonatomic) NSUUID *uniqueIdentifier;
@end

@interface HFItem : NSObject
@end

typedef struct HUGridSize {
	long long rowsDown;
	long long columnsAcross;
} HUGridSize;

@interface HFItemManager : NSObject
@property (nonatomic,readonly) NSSet *allItems; 
@property (nonatomic,readonly) NSSet *allDisplayedItems; 
- (instancetype)initWithDelegate:(id)arg1 sourceItem:(id)arg2;
@property (nonatomic,retain) NSArray *itemProviders;
@property (assign,nonatomic) id<HFItemManagerDelegate> delegate;
@property (nonatomic,retain) HFItem *sourceItem;
@end

@interface HFItemProvider : NSObject
@end

@interface HUCCPredictionsItemProvider : HFItemProvider
- (instancetype)initWithHome:(id)arg1 predictionManager:(id)arg2 itemLimit:(NSUInteger)arg3;
-(id)reloadItems;
@property (nonatomic,retain) NSMutableSet *allItems;
@end

@interface HMHome : NSObject
- (id)userActionPredictionController;
@end

@interface HUCCPredictionManager : NSObject
@property (assign,nonatomic) BOOL wasQueriedForInFlightPredictions;
-(id)initWithHome:(id)arg1 predictionController:(id)arg2 delegate:(id)arg3 predictionLimit:(unsigned long long)arg4;
@end

@interface HFPlaceholderItem : HFItem
@end

@interface HFMediaAccessoryItem : HFItem
@property (nonatomic,readonly) id<HFHomeKitObject> homeKitObject;
@end

@interface HFHomeItem : HFItem
@end

@interface HMAccessory : NSObject <HFHomeKitObject>
@property (nonatomic,copy) NSString *name;
@end

@interface HUGridCell : UICollectionViewCell
@property (nonatomic,retain) HFItem *item;
@end

@interface HMHomeManager : NSObject
@end

@class HFHomeKitDispatcher;

@protocol HFHomeManagerObserver
@optional
- (void)homeManager:(HMHomeManager *)arg1 didUpdateLocationSensingAvailability:(_Bool)arg2;
- (void)homeManagerDidFinishUnknownChange:(HMHomeManager *)arg1;
- (void)homeManagerDidFinishInitialDatabaseLoad:(HMHomeManager *)arg1;
- (void)homeKitDispatcher:(HFHomeKitDispatcher *)arg1 manager:(HMHomeManager *)arg2 didChangeHome:(HMHome *)arg3;
@end


@interface HFHomeKitDispatcher : NSObject
+ (id)sharedDispatcher;
- (void)addHomeManagerObserver:(id<HFHomeManagerObserver>)observer;
@end