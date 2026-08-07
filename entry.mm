#import "MyGoldAPI.h"

__attribute__((constructor))
static void initializeMyGoldAPI(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[MyGoldAPI sharedInstance] startLoginFlow];
    });
}
