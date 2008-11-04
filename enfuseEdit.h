//
//	enfuseEdit.h
//	enfuseEdit
//
//	Created by valery brasseur on 28/09/08.
//	Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "ApertureEditPlugIn.h"
#import "ApertureEditManager.h"

#import "ExportOptionsController.h"
#import "alignStackTask.h"
#import "enfuseTask.h"
#import "TaskWrapper.h"

@interface enfuseEdit : NSObject <ApertureEditPlugIn>
{
	// The cached API Manager object, as passed to the -initWithAPIManager: method.
	id _apiManager; 
	
	// The cached Aperture Export Manager object - you should fetch this from the API Manager during -initWithAPIManager:
	NSObject<ApertureEditManager, PROAPIObject> *_editManager; 
		
	// Top-level objects in the nib are automatically retained - this array
	// tracks those, and releases them
	NSArray *_topLevelNibObjects;
	
	// Outlets to your plug-ins user interface
	IBOutlet NSWindow *_editWindow;
	
	 IBOutlet NSTableView* mTableImage;
	 IBOutlet NSArrayController *mImageArrayCtrl;
	
		IBOutlet NSButton *_revertButton;
	IBOutlet NSButton *_cancelButton;
	IBOutlet NSButton *_doneButton;

  // enfuse GUI
  IBOutlet NSSlider* mContrastSlider;
  IBOutlet NSStepper* mContrastStepper;
  IBOutlet NSTextField* mContrastTextField;
  IBOutlet NSSlider* mExposureSlider;
  IBOutlet NSStepper* mExposureStepper;
  IBOutlet NSTextField* mExposureTextField;
  IBOutlet NSSlider* mSaturationSlider;
  IBOutlet NSStepper* mSaturationStepper;
  IBOutlet NSTextField* mSaturationTextField;
  
  IBOutlet NSButton* mEnfuseButton;

  IBOutlet NSSlider* mMuSlider;
  IBOutlet NSStepper* mMuStepper;
  IBOutlet NSTextField* mMuTextField;

  IBOutlet NSSlider* mSigmaSlider;
  IBOutlet NSStepper* mSigmaStepper;
  IBOutlet NSTextField* mSigmaTextField;

  // expert options ...
  IBOutlet NSTextField* mContrastWindowSizeTextField;
  IBOutlet NSTextField* mMinCurvatureTextField;

   // autoalign options
  IBOutlet NSButton* mAutoAlign;
  IBOutlet NSButton* mAssumeFisheye;
  IBOutlet NSButton* mOptimizeFOV;
  IBOutlet NSTextField* mControlPoints;
  IBOutlet NSTextField* mGridSize;
  
    // metadata ... 
  IBOutlet NSButton* mCopyMeta;
  IBOutlet NSButton* mCopyAperture;
  IBOutlet NSButton* mCopyShutter;
  IBOutlet NSButton* mCopyFocal;

  //
  IBOutlet NSProgressIndicator *mProgressIndicator;
  IBOutlet NSTextField *mProgressText;

	 // ouput options
  IBOutlet NSPopUpButton *mOutFormat;
  IBOutlet NSTextField *mOutQuality;
  IBOutlet NSTextField *mOutFile;
  IBOutlet NSTextField *mAppendTo;
  IBOutlet NSMatrix *mOutputType;
  IBOutlet NSSlider *mOutputQualitySlider; 

	 IBOutlet ExportOptionsController* exportOptionsSheetController;
	
	@private
	NSMutableArray *images;

	// Tracking images that Aperture writes to disk
	//NSMutableArray *exportedImagePaths;	
	NSMutableDictionary *_cacheImagesInfos;
	
	// task handling
  NSString *_enfusePath; 
  BOOL findRunning;
  
  //TaskWrapper *enfuseTask;
  
  	alignStackTask* aligntask;
	enfuseTask* enfusetask;


      NSString* _outputfile;
    NSString* _tmpfile;
    NSString* _tmppath;

	NSMutableDictionary* useroptions;
}

- (IBAction)_cancelEditing:(id)sender;
- (IBAction)_doneEditing:(id)sender;

- (IBAction)about: (id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)enfuse: (id)sender;

- (IBAction)takeSaturation: (id)sender;
- (IBAction)takeContrast: (id)sender;
- (IBAction)takeExposure: (id)sender;

- (IBAction)takeSigma: (id)sender;
- (IBAction)takeMu: (id)sender;

- (IBAction)openPreferences:(id)sender;

- (IBAction)openPresets: (id)sender;
- (IBAction)savePresets: (id)sender;

-(NSString*)outputfile;
-(void)setOutputfile:(NSString *)file;
-(NSString*)tempfile;
-(void)setTempfile:(NSString *)file;
-(NSString*)temppath;
-(void)setTempPath:(NSString *)file;


-(void)alignFinish:(int)status;
- (void)runEnfuse;
- (void)doEnfuse;

@end
