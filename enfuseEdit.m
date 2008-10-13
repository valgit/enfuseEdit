//
//	enfuseEdit.m
//	enfuseEdit
//
//	Created by valery brasseur on 28/09/08.
//	Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "enfuseEdit.h"

// Categories : private methods
@interface enfuseController (Private)

-(void)setDefaults;
-(void)getDefaults;

@end

@implementation enfuseEdit

//---------------------------------------------------------
// initWithAPIManager:
//
// This method is called when a plug-in is first loaded, and
// is a good point to conduct any checks for anti-piracy or
// system compatibility. This is also your only chance to
// obtain a reference to Aperture's export manager. If you
// do not obtain a valid reference, you should return nil.
// Returning nil means that a plug-in chooses not to be accessible.
//---------------------------------------------------------

- (id)initWithAPIManager:(id<PROAPIAccessing>)apiManager
{
	if (self = [super init])
	{
		_apiManager	= apiManager;
		_editManager = [[_apiManager apiForProtocol:@protocol(ApertureEditManager)] retain];
		if (!_editManager)
			return nil;
				
		// Finish your initialization here
		NSLog(@"%s",__PRETTY_FUNCTION__);
		// Create the array we'll use to hold the paths to our images
		images = [[NSMutableArray alloc] init];
			// allocate the cache ...
		_cacheImagesInfos = [[NSMutableDictionary alloc] init];
		// task ...
		findRunning=NO;
		enfuseTask=nil;
	}
	
	return self;
}

- (void)dealloc
{
	[images release];

	// Release the top-level objects from the nib.
	[_topLevelNibObjects makeObjectsPerformSelector:@selector(release)];
	[_topLevelNibObjects release];
    [_cacheImagesInfos release];
	
	[_editManager release];
	
	[super dealloc];
}

// maybe store some default ?
+ (void)initialize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                @"YES", @"useCIECAM",
                @"default", @"cachesize",
                @"default", @"blocksize",
                nil];

    [defaults registerDefaults:appDefaults];
}

// when first launched, this routine is called when all objects are created
// and initialized.  It's a chance for us to set things up before the user gets
// control of the UI.
-(void)awakeFromNib
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
    findRunning=NO;
    enfuseTask=nil;
#if 0
	NSString *path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] bundlePath],
		/*@"/greycstoration.app/Contents/MacOS/greycstoration"*/
		@"/enfuse/enfuse"];
	
	// check for enfuse binaries...
	if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
		NSString *alert = [path stringByAppendingString: @" is not executable!"];
		NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
	}
#endif
	
	[_editWindow center];
//	[window makeKeyAndOrderFront:nil];
	
	// this allows us to declare which type of pasteboard types we support
	//[mTableImage setDataSource:self];
	[mTableImage setRowHeight:128]; // have some place ...

	// theIconColumn = [table tableColumnWithIdentifier:@"icon"];
	// [ic setImageScaling:NSScaleProportionally]; // or NSScaleToFit
	[self reset:_revertButton];
}


#pragma mark -
// UI Methods
#pragma mark UI Methods

- (NSWindow *)editWindow
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (_editWindow == nil)
	{
		NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
		NSNib *myNib = [[NSNib alloc] initWithNibNamed:@"enfuseEdit" bundle:myBundle];
		if ([myNib instantiateNibWithOwner:self topLevelObjects:&_topLevelNibObjects])
		{
			[_topLevelNibObjects retain];
		}
		[myNib release];

	//NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
	_enfusePath = [[NSString stringWithFormat:@"%@%@",[[myBundle infoDictionary] objectForKey:@"NSBundleResolvedPath"],
		@"/Contents/MacOS/enfuse"] retain];

	NSLog(@"%s path is : %@",__PRETTY_FUNCTION__,_enfusePath);
	
	}
	
	return _editWindow;
}

#pragma mark -
// Edit Session Methods
#pragma mark Edit Session Methods

- (void)beginEditSession
{

	int index, count = [[_editManager selectedVersionIds] count];
	NSLog(@"%s selected : %d",__PRETTY_FUNCTION__,count);
	
#if 0
	for (index=0; index < count; index++)
	{
		//[images addObject:[NSNull null]];
    // get the version ID ...	
		NSString *versionID = [[[_editManager selectedVersionIds] objectAtIndex:index] retain];
    
    // Get the thumbnail from Aperture
    NSImage *thumbnail = [[_editManager thumbnailForVersion:versionID size:kExportThumbnailSizeThumbnail] retain];
    if ( nil == thumbnail) {
		   NSLog(@"%s : can't get thumbnail",__PRETTY_FUNCTION__);
		   NSBundle *bundle = [NSBundle bundleForClass:[self class]];
       NSString *noThumbPath = [bundle pathForResource:@"image_broken" ofType:@"png" inDirectory:nil];            
       NSImage *nothumb = [[[NSImage alloc] initWithContentsOfFile:noThumbPath] autorelease];
       thumbnail = nothumb;
	  }
    // Get the path
    NSString *path = [_editManager pathOfEditableFileForVersion:versionID];
    // Get properties ...
    NSDictionary *properties = [_editManager propertiesWithoutThumbnailForVersion:versionID];
    NSLog(@"%s : props are %@", __PRETTY_FUNCTION__, properties);
	NSArray *editproperties = [_editManager editableVersionsOfVersions:[NSArray arrayWithObject:versionID]  /*requestedFormat:kApertureImageFormatTIFF16*/ stackWithOriginal:YES];
	NSLog(@"%s edit props are : %@",__PRETTY_FUNCTION__,editproperties);
	NSString *text = [[[properties objectForKey:kExportKeyVersionName] retain ] autorelease];
    NSNumber *enable = [NSNumber numberWithBool: YES];
    // store all the infos...
    NSMutableDictionary *newImage = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
        enable,@"enable",path,@"file",text,@"text",thumbnail,@"thumb",nil] retain];
    NSLog(@"%s vID : %@ {path=%@}",__PRETTY_FUNCTION__,versionID,path);
	//[mImageArrayCtrl addObject:newImage];
	[self insertObject:newImage inImagesAtIndex:index];
	//[images addObject:newImage];
	}
#endif
}

- (void)editManager:(id<ApertureEditManager>)editManager didImportImageAtPath:(NSString *)path versionUniqueID:(NSString *)versionUniqueID
{
	NSLog(@"%s",__PRETTY_FUNCTION__);

	// add some keywords ...
	NSArray *version = [NSArray arrayWithObject:versionUniqueId];
	NSString *keyword = @"Enfuse";
	NSArray *keywordHierarchy = [NSArray arrayWithObject:keyword];
	NSArray *keywords =  [NSArray arrayWithObject:keywordHierarchy];
	[_editManager addHierarchicalKeywords:keywords toVersions:version];
    [_editManager endEditSession];
}

- (void)editManager:(id<ApertureEditManager>)editManager didNotImportImageAtPath:(NSString *)path error:(NSError *)error;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// should we display something here ?
	// Tell Aperture to cancel
	[_editManager cancelEditSession];
}

#pragma mark -
// Actions
#pragma mark Actions


- (IBAction)_cancelEditing:(id)sender
{	
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (findRunning) { 
		[enfuseTask stopProcess];
		// Release the memory for this wrapper object
		[enfuseTask release];
		enfuseTask=nil;
	}
  // maybe we should to some cleanup ?
  //- (void)deleteVersions:(NSArray *)versionUniqueIDs;

	// Tell Aperture to cancel
	[_editManager cancelEditSession];
}

- (IBAction)_doneEditing:(id)sender
{
  NSLog(@"%s",__PRETTY_FUNCTION__);

  // maybe we should to some cleanup ?
  //- (void)deleteVersions:(NSArray *)versionUniqueIDs;

  if ([_editManager canImport]) {
    NSLog(@"%s will import",__PRETTY_FUNCTION__);
	//NSString *enfuseImage= @"/Users/valery/Pictures/working/test.tiff"; // TODO
	[_editManager importImageAtPath:[self outputfile] referenced:YES stackWithVersions:[_editManager selectedVersionIds]];
    // - (id)importedVersionIds;


  } else {
    NSLog(@"%s can't import !",__PRETTY_FUNCTION__);
    // should we display something here ?
    [_editManager endEditSession];
  }
#if 0
	// The whole point of this method is to actually write out the changes the user has made
	int i, count = [[_editManager selectedVersionIds] count];
	NSLog(@"%s selected : %d",__PRETTY_FUNCTION__,count);
	for (i = 0; i < count; i++)
	{
		NSString *filePath = [images objectAtIndex:i];
		if ([filePath isKindOfClass:[NSString class]])
		{
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];


			// Tag this image with a keyword stating it was edited, and a custom metadata value saying how.
			//NSString *versionUniqueId = [[_editManager editableVersionIds] objectAtIndex:_editingIndex];
			if (versionUniqueId != nil)
			{
				NSArray *version = [NSArray arrayWithObject:versionUniqueId];
				NSString *keyword = @"Edited";
				NSArray *keywordHierarchy = [NSArray arrayWithObject:keyword];
				NSArray *keywords =  [NSArray arrayWithObject:keywordHierarchy];
				[_editManager addHierarchicalKeywords:keywords toVersions:version];

				//NSDictionary *customMetadata = [NSDictionary dictionaryWithObject:[[_currentSettings objectAtIndex:_editingIndex] stringValue] forKey:@"SampleEditPlugIn Pixelate Value"];
				[_editManager addCustomMetadata:customMetadata toVersions:version];
			}

			[pool release];
		}
	}
#endif				
}


#pragma mark -
#pragma mark table binding 

//speak well !	
-(NSString *)pluralImagesToProcess;
{
	return ([[_editManager selectedVersionIds] count] <= 1)? @"" : @"s";
}

// KVC compliant for array
- (unsigned)countOfImages
{
	//NSLog(@"%s edit image count: %d",__PRETTY_FUNCTION__,[images count]);
	
	//return [images count];
	return [[_editManager selectedVersionIds] count];
}

// minimum ...
#if 0
//    Get the path to the editable version
    NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:0];
    NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
    NSArray *properties = [_editManager editableVersionsOfVersions:[NSArray arrayWithObject:versionUniqueID]  requestedFormat:kApertureImageFormatTIFF16 stackWithOriginal:YES];
    
#endif

// KVC compliant for array
-(NSDictionary *)objectInImagesAtIndex:(unsigned)index
{
	NSString *indexkey = [NSString stringWithFormat:@"%d",index];
	NSDictionary *cachedata;
	
	//NSLog(@"%s for: %d",__PRETTY_FUNCTION__,index);
	cachedata = [_cacheImagesInfos objectForKey:indexkey];
	if (cachedata != nil) {
		NSLog(@"%s as cache data for %d",__PRETTY_FUNCTION__,index);
		return cachedata;
	}

	NSString *_versionID;
	NSImage* image;
	NSString *text;
	NSNumber *enable = [NSNumber numberWithBool: YES];
	NSLog(@"%s for: %d",__PRETTY_FUNCTION__,index);
	//NSMutableDictionary *dict = [images objectAtIndex:index];
	//NSLog(@"dict : %@",[dict objectForKey:@"thumb"]);
	// TODO : better check for null ...
	   //    Get the ID for the selected version
    _versionID = [[[_editManager selectedVersionIds] objectAtIndex:index] retain];
    
    //    Get the thumbnail from Aperture
    image = [[_editManager thumbnailForVersion:_versionID size:kExportThumbnailSizeThumbnail] retain];
	//image = nil;
	if ( nil == image) {
		NSLog(@"%s : can't get thumbnail",__PRETTY_FUNCTION__);
	}
	// TODO : grab real value !
	//text = [[@"test"  retain ] autorelease];
	// Get properties ...
    NSDictionary *properties = [_editManager propertiesWithoutThumbnailForVersion:_versionID];
    //NSLog(@"%s : props are %@", __PRETTY_FUNCTION__, properties);
	NSString *path = [_editManager pathOfEditableFileForVersion:_versionID];
	NSString *exportName = [[[properties objectForKey:kExportKeyVersionName] retain ] autorelease];
	//kExportKeyEXIFProperties
	
	NSDictionary *exif = [properties objectForKey:kExportKeyEXIFProperties];
	//NSLog(@"%s : exif are %@", __PRETTY_FUNCTION__, exif);
	if(exif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
		NSString *focalLengthStr, *fNumberStr, *exposureTimeStr,*exposureBiasStr;
		//NSLog(@"the exif data is: %@", [exif description]);
		NSNumber *focalLengthObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFocalLength];
		if (focalLengthObj) {
			focalLengthStr = [NSString stringWithFormat:@"%@mm", [focalLengthObj stringValue]];
		} else focalLengthStr = @"";
		NSNumber *fNumberObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFNumber];
		if (fNumberObj) {
			fNumberStr = [NSString stringWithFormat:@"F%@", [fNumberObj stringValue]];
		} else fNumberStr = @"--";
		NSNumber *exposureTimeObj = (NSNumber *)[exif objectForKey:(NSString *)kCGImagePropertyExifExposureTime];
		if (exposureTimeObj) {
			exposureTimeStr = [NSString stringWithFormat:@"1/%.0f", (1/[exposureTimeObj floatValue])];
		} else exposureTimeStr = @"--";
		NSNumber *exposureBiasObj = (NSNumber *)[exif objectForKey:(NSString *)kCGImagePropertyExifExposureBiasValue];
		if (exposureBiasObj) {
			exposureBiasStr = [NSString stringWithFormat:@"Bias:%@", [exposureBiasObj stringValue]];
		} else exposureBiasStr = @"--";
		
		text = [NSString stringWithFormat:@"%@\n%@ / %@ @ %@", exportName,
			focalLengthStr,exposureTimeStr,fNumberStr];
	} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
	else {
		text = [NSString stringWithFormat:@"%@\n no exif", exportName];			
	}
	
   // text = [NSString stringWithFormat:@"%@ %@",exportName,path];
	
	cachedata = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",text,@"text",image,@"thumb",nil];  
	[_cacheImagesInfos setValue:cachedata forKey:indexkey];
	//NSLog(@"%s cache size is %d",__PRETTY_FUNCTION__,[_cacheImagesInfos count]);
	return cachedata;
}

// 
-(void)insertObject:(id)obj inImagesAtIndex:(unsigned)index;
{
	NSLog(@"%s obj is : %@",__PRETTY_FUNCTION__,obj);
	[images insertObject: obj  atIndex: index];
}

-(void)removeObjectFromImagesAtIndex:(unsigned)index;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	[images removeObjectAtIndex: index];
}

-(void)replaceObjectInImagesAtIndex:(unsigned)index withObject:(id)obj;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	[images replaceObjectAtIndex: index withObject: obj];
}

#pragma mark -
#pragma mark Action GUI

- (IBAction)reset:(id)sender
{
        NSLog(@"%s",__PRETTY_FUNCTION__);

        [mContrastSlider setFloatValue:0.0]; // (0 <= WEIGHT <= 1).  Default: 0
        [self takeContrast:mContrastSlider];

        [mExposureSlider setFloatValue:1.0]; // 0 <= WEIGHT <= 1).  Default: 1
        [self takeExposure:mExposureSlider];

        [mSaturationSlider setFloatValue:0.2]; // (0 <= WEIGHT <= 1).  Default: 0.2
        [self takeSaturation:mSaturationSlider];

        [mMuSlider setFloatValue:0.5]; // mu (0 <= MEAN <= 1).  Default: 0.5
        [self takeMu:mMuSlider];

        [mSigmaSlider setFloatValue:0.2]; // sigma (SIGMA > 0).  Default: 0.2
        [self takeSigma:mSigmaSlider];
}

- (IBAction) about: (IBOutlet)sender;
{
        NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (IBAction) takeSaturation: (IBOutlet)sender;
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
        float theValue = [sender floatValue];
        [mSaturationTextField setFloatValue:theValue];
        [mSaturationStepper setFloatValue:theValue];
        [mSaturationSlider setFloatValue:theValue];
}

- (IBAction) takeContrast: (IBOutlet)sender;
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
        float theValue = [sender floatValue];
        [mContrastTextField setFloatValue:theValue];
        [mContrastStepper setFloatValue:theValue];
        [mContrastSlider setFloatValue:theValue];
}

- (IBAction) takeExposure: (IBOutlet)sender;
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
        float theValue = [sender floatValue];
        [mExposureTextField setFloatValue:theValue];
        [mExposureStepper setFloatValue:theValue];
        [mExposureSlider setFloatValue:theValue];
}

- (IBAction) takeSigma: (IBOutlet)sender;
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
        float theValue = [sender floatValue];
        [mSigmaTextField setFloatValue:theValue];
        [mSigmaStepper setFloatValue:theValue];
        [mSigmaSlider setFloatValue:theValue];
}

- (IBAction) takeMu: (IBOutlet)sender;
{
        //NSLog(@"%s",__PRETTY_FUNCTION__);
        float theValue = [sender floatValue];
        [mMuTextField setFloatValue:theValue];
        [mMuStepper setFloatValue:theValue];
        [mMuSlider setFloatValue:theValue];
}

- (IBAction) openPresets: (IBOutlet)sender;
{
// - (id)userDefaultsObjectForKey:(NSString *)key;

        NSLog(@"%s",__PRETTY_FUNCTION__);
        NSOpenPanel *open = [NSOpenPanel openPanel];
        [open setTitle:@"Load Presets"];
        [open setAllowsMultipleSelection:NO];
        if([open runModalForTypes:[NSArray arrayWithObject:@"enf"]] == NSOKButton){
                NSString *file = [[open filenames] objectAtIndex:0];

                NSData *data = [NSData dataWithContentsOfFile:file];
                [self readFromData:data ofType:@"xml"];
                [data release];
        }
}

- (IBAction) savePresets: (IBOutlet)sender;
{
// - (void)setUserDefaultsValue:(id)value forKey:(NSString *)key;

        NSLog(@"%s",__PRETTY_FUNCTION__);
        NSSavePanel *save = [NSSavePanel savePanel];
        [save setTitle:@"Save Presets"];
        [save setRequiredFileType:@"enf"];
        if([save runModal] == NSOKButton){
                NSString *file = [save filename];

                NSData* data = [self dataOfType:@"xml"];
                [data writeToFile:file atomically:YES ];
                [data release];
        }
}

- (IBAction)openPreferences:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
       // [[MyPrefsWindowController sharedPrefsWindowController] showWindow:nil];
}

- (IBAction) enfuse: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (findRunning) {
		NSLog(@"already running");
		return;
	   } else {
		   // If the task is still sitting around from the last run, release it
		   if (enfuseTask!=nil)
			   [enfuseTask release];
		   // Let's allocate memory for and initialize a new TaskWrapper object, passing
		   // in ourselves as the controller for this TaskWrapper object, the path
		   // to the command-line tool, and the contents of the text field that
		   // displays what the user wants to search on
		   NSMutableArray *args = [NSMutableArray array];
		   
		   [args addObject:_enfusePath];
		   
		   [args addObject:@"-o"];
		   NSString *outputfile = NSHomeDirectory();
                   outputfile = [outputfile stringByAppendingPathComponent:@"Pictures"];
		   NSString *tempString = [[NSProcessInfo processInfo] globallyUniqueString];
      		   outputfile = [outputfile stringByAppendingPathComponent:tempString];
		   [self setOutputfile:[NSString stringWithFormat:@"%@.%@",tempFilename,@"tiff"]]; // TODO
		   [args addObject:[self outputfile]]; // TODO
		   
		   //int i, count = [[_editManager selectedVersionIds] count];
		   //NSLog(@"%s adding selected : %d",__PRETTY_FUNCTION__,count);
		   // Tell Aperture to make an editable version of these images. If this version is already editable, this method won't generate a new version
		   // but will still return the appropriate properties.
		   // format ? requestedFormat:kApertureImageFormatTIFF8
		   NSArray *properties = [_editManager editableVersionsOfVersions:[_editManager selectedVersionIds] stackWithOriginal:YES];		   
		   //NSLog(@"%s editables propos are : << %@ >>",__PRETTY_FUNCTION__,properties);
		   
		   int i, count = [[_editManager editableVersionIds]  count];
		   NSLog(@"%s edit count :%d",__PRETTY_FUNCTION__,count );
		   
		   for (i = 0; i < count; i++) {
			  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			
			  //NSDictionary *imageProperties = [properties objectAtIndex:0];
				//    Get the path to the editable version
			   NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:i];
			   NSLog(@"%s edit %@",__PRETTY_FUNCTION__,editableVersionId);
			   NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
			   [args addObject:imagePath];
			   //NSLog(@"%s : %@ %@ %@ %@",__PRETTY_FUNCTION__,
				//	versionID,editableVersionId,imagePath,path);
			 [pool release];
		   }
		   [args addObject:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];
		   
		   [args addObject:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
		   [args addObject:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];
		   
		   NSLog(@"%s will exec : %@",__PRETTY_FUNCTION__,args);

	   }
}

#pragma mark -
#pragma mark TaskWrapper

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
   if ([output hasPrefix:@"Generating"] || [output hasPrefix:@"Collapsing"]  ||
        [output hasPrefix: @"Loading next image"] || [output hasPrefix: @"Using"] ) {
        [mProgessIndicator incrementBy:1.0];
    } 
}

// A callback that gets called when a TaskWrapper is launched, allowing us to do any setup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processStarted
{
   findRunning=YES;
    // clear the results
    //[resultsTextField setString:@""];
    // change the "Sleuth" button to say "Stop"
    //[mRestoreButton setTitle:@"Stop"];
    [mEnfuseButton setEnabled:NO];
    [mProgress startAnimation:self];
#ifdef _PROGRESSPANEL_
		   [[myProgress window] center];
		   [[myProgress window] makeKeyAndOrderFront:nil]; // nspanel was originally hidden in Interface Builder
		   [[myProgress window] display];
#endif
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished:(int)status
{
    [mProgress stopAnimation:self];
    [mProgress setDoubleValue:0];

	NSLog(@"%s status is : %d",__PRETTY_FUNCTION__,status);
    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    [mEnfuseButton setEnabled:YES];
#ifdef _PROGRESSPANEL_
    [[myProgress window] orderOut:nil];
#endif
}

-(NSString*)outputfile;
{
        return _outputfile;
}

-(void)setOutputfile:(NSString *)file;
{
        if (_outputfile != file) {
                [_outputfile release];
        _outputfile = [file copy];
        }
}

@end

@implementation enfuseEdit (Private)

// write back the defaults ...
-(void)setDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
              [standardUserDefaults setObject:[mOuputFile stringValue] forKey:@"outputDirectory"];
              [standardUserDefaults setObject:[mOutFile stringValue] forKey:@"outputFile"];
              [standardUserDefaults setObject:[mAppendTo stringValue] forKey:@"outputAppendTo"];
              [standardUserDefaults setObject:[mOutQuality stringValue] forKey:@"outputQuality"];
              [standardUserDefaults synchronize];
        }
}

// read back the defaults ...
-(void)getDefaults;
{
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];

        if (standardUserDefaults) {
              [mOuputFile setStringValue:[standardUserDefaults objectForKey:@"outputDirectory"]];
              [mOutFile setStringValue:[standardUserDefaults objectForKey:@"outputFile"]];
              [mAppendTo setStringValue:[standardUserDefaults objectForKey:@"outputAppendTo"]];
              [mOutQuality setStringValue:[standardUserDefaults objectForKey:@"outputQuality"]];
        }
}

@end
