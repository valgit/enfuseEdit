/*
 * interface to taskwrapper for align_stack_process
 */
#import <Cocoa/Cocoa.h>
#import "TaskWrapper.h"
#import "TaskProgressInfo.h"

@interface alignStackTask : NSObject  <TaskWrapperController>
{
  id _delegate;
   
  @private
  NSProgressIndicator* progress;
  TaskProgressInfo* mProgressInfo;
  
  BOOL findRunning;
  TaskWrapper *alignTask;

  //NSConditionLock* lock; // 0 = no elements, 1 = elements
  NSMutableArray *args;
  
  NSString *align_path;
  BOOL cancel;

  int state;
}

- (id)initWithPath:(NSString*)tmp_path;
- (void)dealloc;

- (id)delegate;
- (void)setDelegate:(id)new_delegate;

- (void)setProgress:(NSProgressIndicator *)mProgressIndicator;
- (void)runAlign;

- (void)setCancel:(BOOL)state;
- (BOOL)cancel;

//
// - (BOOL)movie:(QTMovie *)movie shouldContinueOperation:(NSString *)op withPhase:(QTMovieOperationPhase)phase atPercent:(NSNumber *)percent 
- (void)setGridSize:(NSString*)gridsize;
- (void)setControlPoints:(NSString*)controls;
- (void)addFile:(NSString*)file;

// TaskWrapper protocol
- (void)appendOutput:(NSString *)output;
- (void)processStarted;
//- (void)processFinished;

-(void)finishedAligning:(NSNumber *)status;
- (void)processFinished:(int)status;

@end

// delegate  interface
@interface NSObject (alignStackTaskDelegate)

-(void)alignFinish:(int)status;

@end 

