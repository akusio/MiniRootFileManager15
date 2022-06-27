#import "FileManager.h"
#import "AXFile.h"
#import "ViewController.h"

@implementation FileManager

+(NSString*)home{
    
    return NSHomeDirectory();
    
}

+(BOOL)write:(NSString*)path WithString:(NSString*)str{
    
    return [str writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
}



+(BOOL)append:(NSString*)path WithString:(NSString*)str{
    
    NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:path];
    
    if(fh == nil){
        return NO;
    }
    [fh seekToEndOfFile];
    NSData* writeData = [str dataUsingEncoding:NSUTF8StringEncoding];
    [fh writeData:writeData];
    [fh closeFile];
    return YES;
    
}



+(NSString*)read:(NSString*)path{
    
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
}



+(BOOL)existsFile:(NSString*)path{
    
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL directory;
    
    return [fm fileExistsAtPath:path isDirectory:&directory];
    
}



+(BOOL)isDirectory:(NSString*)path{
    
    NSFileManager* fm = [NSFileManager defaultManager];
    BOOL directory;
    [fm fileExistsAtPath:path isDirectory:&directory];
    
    return directory;
    
}



+(BOOL)createFile:(NSString*)path{
    getRootThisProc();
    BOOL ret = [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
    noRoot();
    return ret;
}



+(BOOL)createDirectory:(NSString*)path{
    getRootThisProc();
    BOOL ret = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    noRoot();
    return ret;
}



+(NSArray<NSString*>*)fileList:(NSString*)path{
    
    getRootThisProc();
    NSArray<NSString*>* ret = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    noRoot();
    return ret;
    
}

+(NSArray<AXFile*>*)getAXFileList:(NSString*)path{
    
    NSArray<NSString*>* files = [FileManager fileList:path];
    NSMutableArray* ret = [NSMutableArray array];
    
    for(NSString* fileName in files){
        
        AXFile* af = [[AXFile alloc] initWithPath:[path stringByAppendingFormat:@"%@", fileName]];
        NSLog(@"AXFile : %@", [path stringByAppendingFormat:@"%@", fileName]);
        [ret addObject:af];
        
    }
    
    return [ret copy];
    
}



+(BOOL)removeFile:(NSString*)path{
    
    getRootThisProc();
    BOOL ret = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    noRoot();
    return ret;
    
}

+(BOOL)copyFile:(NSString*)src toPath:(NSString*)dst{
    
    getRootThisProc();
    BOOL ret = [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil];
    noRoot();
    return ret;
}

@end
