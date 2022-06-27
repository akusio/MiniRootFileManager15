#ifndef AXFile_h
#define AXFile_h

#import <Foundation/Foundation.h>

@interface AXFile : NSObject

@property (nonatomic) NSString* name;

@property (nonatomic) BOOL isDirectory;

-(id)initWithPath:(NSString*)path;

@end

#endif /* AXFile_h */
