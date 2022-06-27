#import <Foundation/Foundation.h>
#import "AXFile.h"


@interface FileManager : NSObject

//@property(nonatomic)BOOL isClosed;

//@property(nonatomic)BOOL isWriteMode;
+(NSString*)home;

+(BOOL)write:(NSString*)path WithString:(NSString*)str;

+(BOOL)append:(NSString*)path WithString:(NSString*)str;

+(NSString*)read:(NSString*)path;

+(BOOL)existsFile:(NSString*)path;

+(BOOL)isDirectory:(NSString*)path;

+(BOOL)createFile:(NSString*)path;

+(BOOL)createDirectory:(NSString*)path;

+(NSArray<NSString*>*)fileList:(NSString*)path;

+(BOOL)removeFile:(NSString*)path;

+(BOOL)copyFile:(NSString*)src toPath:(NSString*)dst;

+(NSArray<AXFile*>*)getAXFileList:(NSString*)path;

@end
