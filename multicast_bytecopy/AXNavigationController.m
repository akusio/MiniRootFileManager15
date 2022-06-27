#import "AXNavigationController.h"

@implementation AXNavigationController

-(id)init{
    return [super init];
}

-(id)initWithRootViewController:(UIViewController *)rootViewController{
    
    self = [super initWithRootViewController:rootViewController];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.toolbarHidden = false;
    return self;
    
}

@end
