#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "AXLocationBackgrounder.h"

static AXLocationBackgrounder* g_instance;

@interface AXLocationBackgrounder () <CLLocationManagerDelegate>

@property (nonatomic) CLLocationManager* lm;

@end

@implementation AXLocationBackgrounder

+(void)startBackgrounder{
    
    g_instance = [[AXLocationBackgrounder alloc] init];
    g_instance.lm = [[CLLocationManager alloc] init];
    g_instance.lm.delegate = g_instance;
    g_instance.lm.desiredAccuracy = kCLLocationAccuracyBest;
    g_instance.lm.pausesLocationUpdatesAutomatically = NO;
    
    [g_instance.lm requestAlwaysAuthorization];
    g_instance.lm.allowsBackgroundLocationUpdates = YES;
    [g_instance.lm startUpdatingLocation];
    
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    
}

@end
