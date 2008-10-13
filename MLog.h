 #import <Cocoa/Cocoa.h>

 // #define __BTREMOVE_LOGGING 1

 // #define __BTLOGGING_LEVEL 7

 // #define __BTFORCE_NSLOG 1

 // 0 = log everything
 // 1 = log level 1 ond obove
 // etc.
 // 7 = log nothing
 #if defined(__BTREMOVE_LOGGING)
 #define MLogString(l ,s,...)
 #elif defined(__BTFORCE_NSLOG)
 #define MLogString(l ,s,...) NSLog(@"%d: %@",(l),(s))
 #else
 #define MLogString(l ,s,...) [MLog logFile:__FILE__ lineNumber:__LINE__ level: l
    format:(s),##__VA_ARGS__]
 #endif
 
 @interface MLog: NSObject {
 }
 
 +(void)logFile:(char*)sourceFile lineNumber:int)lineNumber level:(int)level
    format:(NSString*)format,... ;
 +(void)setLogMinLevel:(int)level ;
 @end
