#import <Cocoa/Cocoa.h>

// ProgressInfo object passed back to the delegate
// if it implements shouldContinueOperationWithProgressInfo:
// progressValue will contain a valid NSNumber object with a
// value between 0 and 1.0 when phase is MovieWriterExportPercent
@interface TaskProgressInfo : NSObject
{
@private 
    NSString *displayText;
    NSNumber *progressValue;
    NSError  *taskStatus;
    BOOL     continueOperation;
}

-  (NSString*)displayText;
- (void)setDisplayText:(NSString*)text;

- (NSNumber *)progressValue;
- (void)setProgressValue:(NSNumber *)value;

- (NSError *)taskStatus;
- (void)setTaskStatus:(NSError *)status;

- (BOOL)continueOperation;
- (void)setContinueOperation:(BOOL)value;

@end

// invoked on a delegate to provide progress
@interface NSObject (TaskRunDelegate)

- (BOOL)shouldContinueOperationWithProgressInfo:(TaskProgressInfo*)inProgressInfo;

@end



