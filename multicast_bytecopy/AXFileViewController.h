#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import "FileManager.h"

@interface AXFileViewController : UITableViewController <UITextFieldDelegate>

@property (nonatomic) NSString* currentPath;

-(id)initWithPath:(NSString*)path;

@end
