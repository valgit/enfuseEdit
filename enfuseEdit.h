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
  
  //
  IBOutlet NSPanel *mProgressWindow;
  IBOutlet NSProgressIndicator *mProgress;

	IBOutlet NSPanel *mImportOptionsSheet;
	
	@private
	NSMutableArray *images;

	// Tracking images that Aperture writes to disk
	//NSMutableArray *exportedImagePaths;	
	NSMutableDictionary *_cacheImagesInfos;
	
	// task handling
  NSString *_enfusePath; 
  BOOL findRunning;
  TaskWrapper *enfuseTask;

  NSString* _outputfile;
}

- (IBAction)_cancelEditing:(id)sender;
- (IBAction)_doneEditing:(id)sender;

- (IBAction) about: (IBOutlet)sender;
- (IBAction)reset:(id)sender;

- (IBAction) takeSaturation: (IBOutlet)sender;
- (IBAction) takeContrast: (IBOutlet)sender;
- (IBAction) takeExposure: (IBOutlet)sender;

- (IBAction) takeSigma: (IBOutlet)sender;
- (IBAction) takeMu: (IBOutlet)sender;

- (IBAction)openPreferences:(id)sender;

- (IBAction) openPresets: (IBOutlet)sender;
- (IBAction) savePresets: (IBOutlet)sender;

-(NSString*)outputfile;
-(void)setOutputfile:(NSString *)file;

@end
