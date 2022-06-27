#import "AXFile.h"
#import "FileManager.h"

#import <libgen.h>

@implementation AXFile

-(id)initWithPath:(NSString*)path{
    self = [super init];
    
    self.name = @(basename([path UTF8String]));
    self.isDirectory = [FileManager isDirectory:path];
    
    return self;
}

@end
