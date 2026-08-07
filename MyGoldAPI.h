#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MyGoldAPI : NSObject

@property (nonatomic, strong) NSString *keyName;
@property (nonatomic, strong) NSString *keyExpiry;
@property (nonatomic, strong) NSString *keyVersion;
@property (nonatomic, strong) NSString *packagerStatus;
@property (nonatomic, strong) NSString *currentHWID;

+ (instancetype)sharedInstance;

- (void)startLoginFlow;

- (void)showUDIDPopup;
- (NSString *)getHWID;
- (void)registerUDIDWithCompletion:(void (^)(BOOL success))completion;

- (void)showLoginPopup;
- (void)doLoginWithKey:(NSString *)key completion:(void (^)(BOOL success, NSString *message))completion;

- (void)forcePopupVisibility;

@end
