//
//  enfuseTask.h
//  enfuseGUI
//
//  Created by valery brasseur on 10/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TaskWrapper.h"
#import "TaskProgressInfo.h"

@interface enfuseTask : NSObject <TaskWrapperController>
{
  id _delegate;
   
  @private
  NSProgressIndicator* progress;
  TaskProgressInfo* mProgressInfo;
  
  BOOL findRunning;
  TaskWrapper *enfusingTask;

  //NSConditionLock* lock; // 0 = no elements, 1 = elements
  NSMutableArray *args;
  
  NSString *enfuse_path;
  BOOL cancel;
  
   NSString* _outputfile;
}

-(id)init;
-(void)dealloc;

- (id)delegate;
- (void)setDelegate:(id)new_delegate;

- (void)setProgress:(NSProgressIndicator *)mProgressIndicator;
-(void)runEnfuse;
- (void)setCancel:(BOOL)state;
- (BOOL)cancel;

//
// - (BOOL)movie:(QTMovie *)movie shouldContinueOperation:(NSString *)op withPhase:(QTMovieOperationPhase)phase atPercent:(NSNumber *)percent 
-(NSString*)outputfile;
-(void)setOutputfile:(NSString *)file;

- (void)addArg:(NSString*)arg;
- (void)addFile:(NSString*)file;

// TaskWrapper protocol
- (void)appendOutput:(NSString *)output;
- (void)processStarted;
//- (void)processFinished;

-(void)finishedEnfusing:(NSNumber *)status;
- (void)processFinished:(int)status;

@end

// delegate  interface
@interface NSObject (enfuseTaskDelegate)

-(void)enfuseFinish:(int)status;

@end
