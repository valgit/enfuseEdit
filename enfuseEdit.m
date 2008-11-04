//
//	enfuseEdit.m
//	enfuseEdit
//
//	Created by valery brasseur on 28/09/08.
//	Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "enfuseEdit.h"

#import "NSFileManager-Extensions.h"
#import "TaskProgressInfo.h"

// Categories : private methods
@interface enfuseEdit (Private)

-(void)setDefaults;
-(void)getDefaults;

-(NSString *)initTempDirectory;
-(void)cleanuptempdir;

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
		
		//enfuseTask=nil;
		aligntask = nil;
		
		useroptions = [[NSMutableDictionary alloc] initWithCapacity:5];
		[self setTempPath:[self initTempDirectory]];
	}
	
	return self;
}

- (void)dealloc
{
	[images release];
	
	if (aligntask != nil)
		[aligntask release];
	
	if (enfusetask != nil)
		[enfusetask release];
	
	if (exportOptionsSheetController != nil)
		[exportOptionsSheetController release];
	
	if (useroptions != nil)
		[useroptions dealloc];
	
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
		//_enfusePath = [[NSString stringWithFormat:@"%@%@",[[myBundle infoDictionary] objectForKey:@"NSBundleResolvedPath"],
		//	@"/Contents/MacOS/enfuse"] retain];
		
		//NSLog(@"%s path is : %@",__PRETTY_FUNCTION__,_enfusePath);
		
#if 1 // not quit good for plugin !
		NSString *path = [NSString stringWithFormat:@"%@%@",[myBundle resourcePath],
			@"/align_image_stack"];
		NSLog(@"%s path is : %@",__PRETTY_FUNCTION__,path);
		// check for enfuse binaries...
		if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
			NSString *alert = [path stringByAppendingString: @" is not executable!"];
			NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
			[NSApp terminate:nil];
		}
		
		path = [NSString stringWithFormat:@"%@%@",[myBundle resourcePath],
			@"/enfuse"];
		NSLog(@"%s path is : %@",__PRETTY_FUNCTION__,path);
		
		// check for enfuse binaries...
		if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO){
			NSString *alert = [path stringByAppendingString: @" is not executable!"];
			NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
			[NSApp terminate:nil];
		}		
#endif
		
	}
	
	return _editWindow;
}

#pragma mark -
// Edit Session Methods
#pragma mark Edit Session Methods

- (void)beginEditSession
{
	
	int count = [[_editManager selectedVersionIds] count];
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
	NSArray *version = [NSArray arrayWithObject:versionUniqueID];
	
	if ([[useroptions valueForKey:@"addKeyword"] boolValue]) {
		// add some keywords ...
		
		NSString *keyword = [useroptions valueForKey:@"keyword"] /*@"Enfuse"*/;
			NSArray *keywordHierarchy = [NSArray arrayWithObject:keyword];
			NSArray *keywords =  [NSArray arrayWithObject:keywordHierarchy];
			[_editManager addHierarchicalKeywords:keywords toVersions:version];
			
	}

// and some metadata
NSDictionary *customMetadata = [NSDictionary dictionaryWithObject:[mContrastSlider stringValue] 
														   forKey:@"Contrast"];
[_editManager addCustomMetadata:customMetadata toVersions:version];

// do some cleanup
int count = [[_editManager editableVersionIds]  count];
NSLog(@"%s edit count :%d to be removed",__PRETTY_FUNCTION__,count );
[_editManager deleteVersions:[_editManager editableVersionIds]];

[self cleanuptempdir];

[_editManager endEditSession];
}

- (void)editManager:(id<ApertureEditManager>)editManager didNotImportImageAtPath:(NSString *)path error:(NSError *)error;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	// should we display something here ?
	
	[self cleanuptempdir];
	
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
		NSRunAlertPanel (NSLocalizedString(@"Already Running task Error",@""),
						 NSLocalizedString(@"NYI",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
	}
	// maybe we should to some cleanup ?
	//- (void)deleteVersions:(NSArray *)versionUniqueIDs;
	
	[self cleanuptempdir];
	
	// Tell Aperture to cancel
	[_editManager cancelEditSession];
}

- (IBAction)_doneEditing:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
	if (findRunning) { 
		NSRunAlertPanel (NSLocalizedString(@"Already Running task Error",@""),
						 NSLocalizedString(@"NYI",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
	}
	
	// maybe we should to some cleanup ?
	//- (void)deleteVersions:(NSArray *)versionUniqueIDs;
	
	if ([[useroptions valueForKey:@"importInAperture"] boolValue]) 
		NSLog(@"%s should import",__PRETTY_FUNCTION__);
	
	if ([[useroptions valueForKey:@"stackWithOriginal"] boolValue])
		NSLog(@"%s should stack",__PRETTY_FUNCTION__);
	
	if ([_editManager canImport]) {
		NSLog(@"%s will import",__PRETTY_FUNCTION__);
		//NSString *enfuseImage= @"/Users/valery/Pictures/working/test.tiff"; // TODO
		[_editManager importImageAtPath:[self outputfile] referenced:YES stackWithVersions:[_editManager selectedVersionIds]];
		// - (id)importedVersionIds;
		
		
	} else {
		NSLog(@"%s can't import !",__PRETTY_FUNCTION__);
		[self cleanuptempdir];
		
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
	//no valuated NSString *path = [_editManager pathOfEditableFileForVersion:_versionID];
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
	
	cachedata = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",text,@"text",image,@"thumb",exportName,@"file",nil];  
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
#if 0
	// Method to load the .nib file for the info panel.
    if (!infoPanel) {
        if (![NSBundle loadNibNamed:@"InfoPanel" owner:self])  {
            NSLog(@"Failed to load InfoPanel.nib");
            NSBeep();
            return;
        }
        [infoPanel center];
    }
    [infoPanel makeKeyAndOrderFront:nil];
#endif
	
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

- (IBAction)preferencesSaving:(id)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController AddKeyword]]
				   forKey:@"addKeyword"];
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController ImportInAperture]] 
				   forKey:@"importInAperture"];
	[useroptions setValue:[NSNumber numberWithBool:[exportOptionsSheetController stackWithOriginal]]
				   forKey:@"stackWithOriginal"];
	if ([exportOptionsSheetController AddKeyword])
		[useroptions setObject:[exportOptionsSheetController keyword]
						forKey:@"keyword"];
	else
		[useroptions removeObjectForKey:@"keyword"];
	
	[useroptions setObject:[exportOptionsSheetController exportDirectory]
					forKey:@"exportDirectory"];
	
}

- (IBAction)openPreferences:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	
	if (exportOptionsSheetController == nil) 
		exportOptionsSheetController = [[ExportOptionsController alloc] init ];
	
		  [exportOptionsSheetController setImportInAperture:
			  [[useroptions valueForKey:@"importInAperture"] boolValue]];
		  [exportOptionsSheetController stackWithOriginal:
			  [[useroptions valueForKey:@"stackWithOriginal"] boolValue]];
		  [exportOptionsSheetController setAddKeyword:
			  [[useroptions valueForKey:@"addKeyword"] boolValue]];
		  if ([[useroptions valueForKey:@"addKeyword"] boolValue])
			  [exportOptionsSheetController setKeyword:
				  [useroptions valueForKey:@"keyword"]];
		  
		  if ([useroptions valueForKey:@"exportDirectory"])
			  [exportOptionsSheetController setExportDirectory:
				  [useroptions valueForKey:@"exportDirectory"]];
		  else {
			  NSString *outputDirectory;
			  outputDirectory = NSHomeDirectory();
			  outputDirectory = [outputDirectory stringByAppendingPathComponent:@"Pictures"];
			  [exportOptionsSheetController setExportDirectory:outputDirectory];
		  }
		  
		  [exportOptionsSheetController runSheet:[_editManager apertureWindow] selector:@selector(preferencesSaving:) target:self];
}

- (IBAction) enfuse: (IBOutlet)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (findRunning) {
		NSLog(@"already running");
		//NSRunAlertPanel (NSLocalizedString(@"Error",@""),
		//				 NSLocalizedString(@"Process already running",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
		findRunning = NO;
		return;
	   } else {
		   findRunning = YES;
		   if (aligntask != nil) {
			   NSLog(@"%s need to cleanup autoalign ?",__PRETTY_FUNCTION__);
			   [aligntask release];
			   aligntask = nil;
		   }
		   
		   if ([mAutoAlign state] == NSOnState) {
			   NSLog(@"%s need to autoalign",__PRETTY_FUNCTION__);
			   aligntask = [[alignStackTask alloc] initWithPath:[self temppath]];
			   [aligntask setGridSize:[mGridSize stringValue]];
			   [aligntask setControlPoints:[mControlPoints stringValue]];				   
			   
			   NSLog(@"%s check edit count :%d",__PRETTY_FUNCTION__,[[_editManager editableVersionIds]  count] );
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
				   // if ([[obj valueForKey:@"enable"] boolValue]){
				   
				   //NSDictionary *imageProperties = [properties objectAtIndex:0];
				   //    Get the path to the editable version
				   NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:i];
				   NSLog(@"%s edit %@",__PRETTY_FUNCTION__,editableVersionId);
				   NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
				   [aligntask addFile:imagePath];
				   //NSLog(@"%s : %@ %@ %@ %@",__PRETTY_FUNCTION__,
				   //	versionID,editableVersionId,imagePath,path);
				   [pool release];
				   }
			   
			   [mProgressIndicator setUsesThreadedAnimation:YES];
			   //[mProgressIndicator setIndeterminate:YES];
			   [mProgressIndicator setDoubleValue:0.0];
			   [mProgressIndicator setMaxValue:(1+23*[images count])]; // TOTO : add enfuse step ?
			   [mProgressIndicator startAnimation:self];
			   [mProgressText setStringValue:@"Aligning..."];
			   [aligntask setDelegate:self];
			   [aligntask setProgress:mProgressIndicator]; // needed ?
			   [NSThread detachNewThreadSelector:@selector(runAlign)
										toTarget:aligntask
									  withObject:nil];
			   //[mProgressIndicator stopAnimation:self];
			   //[mProgressIndicator setIndeterminate:NO];
			   // for now !
			   //[mEnfuseButton setEnabled:NO];
			   [mEnfuseButton setTitle:@"Cancel"];
			   return; // testing !
			   } else {
				   NSLog(@"%s need to enfuse",__PRETTY_FUNCTION__);
				   [self doEnfuse];
			   }
		   
		   }
	   }



- (void)doEnfuse
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	NSDictionary* file=nil;
	
	//
	// create the output file name  kExportKeyReferencedMasterPath kExportKeyVersionName
	//
	NSString *filename;
#if 0
	file = [images objectAtIndex:0];
	if (file != nil) {
		filename = [[file valueForKey:@"file"] lastPathComponent ]; 
	} else {
		filename = @"enfused";
	}
#else
	filename = @"enfused";
#endif
	
	// TODO [[mInputFile stringValue] lastPathComponent];
	//NSString *extension = [[filename pathExtension] lowercaseString];
	//NSLog(filename);
	NSString* outputfile;
	
	switch ([[mOutputType selectedCell] tag]) {
		case 0 : /* absolute */
			outputfile = [ [useroptions valueForKey:@"exportDirectory"] /*[mOuputFile stringValue]*/
					 stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:[mOutFile stringValue]
																							 withFormat:@"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
																							  appending:[mAppendTo stringValue] ]];
				break;
											 case 1: /* append */
				outputfile = [ [useroptions valueForKey:@"exportDirectory"] /*[mOuputFile stringValue]*/
						 stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:filename
																								 withFormat:@"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
																								  appending:[mAppendTo stringValue] ]];
					break;
												default:
													NSLog(@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
	}

[self setOutputfile:outputfile];	

// 
// create the enfuse task
if (enfusetask != nil) {
	NSLog(@"%s need to enfuse task",__PRETTY_FUNCTION__);
				[enfusetask release];
				enfusetask = nil;
}

enfusetask = [[enfuseTask alloc] init];

// temporary file for output
[enfusetask setOutputfile:[[NSFileManager defaultManager] tempfilename:@"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/]];

// TODO : check if align_image was run ...
if ([mAutoAlign state] == NSOnState) {
	NSLog(@"%s autoalign was run, get align data",__PRETTY_FUNCTION__);
	// put filenames and full pathnames into the file array
	NSEnumerator *enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath: [self temppath] ] objectEnumerator];
	while (nil != (filename = [enumerator nextObject])) {
		//NSLog(@"file : %@",[filename lastPathComponent]);
		if ([[filename lastPathComponent] hasPrefix:@"align"]) {				
			[enfusetask addFile:[NSString stringWithFormat:@"%@/%@",[self temppath],filename]];
		}
	}
	
} else {
	
	NSLog(@"%s check edit count :%d",__PRETTY_FUNCTION__,[[_editManager editableVersionIds]  count] );
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
		// if ([[obj valueForKey:@"enable"] boolValue]){
		
		//NSDictionary *imageProperties = [properties objectAtIndex:0];
		//    Get the path to the editable version
		NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:i];
		NSLog(@"%s edit %@",__PRETTY_FUNCTION__,editableVersionId);
		NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
		[enfusetask addFile:imagePath];
		//NSLog(@"%s : %@ %@ %@ %@",__PRETTY_FUNCTION__,
		//	versionID,editableVersionId,imagePath,path);
		[pool release];
		}
	}


#if 0
// TODO : check the preferences ...
if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"JPEG"] ) {
	[enfusetask addArg:[NSString stringWithFormat:@"--compression=%@",[mOutQuality stringValue]]];
} else if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"TIFF"] ) {
	[enfusetask addArg:@"--compression=LZW"]; // if jpeg !
}
#else
[enfusetask addArg:@"--compression=LZW"];
#endif

[enfusetask addArg:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];

[enfusetask addArg:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
[enfusetask addArg:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];

[enfusetask addArg:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
[enfusetask addArg:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];

[mProgressIndicator setDoubleValue:0.0];
[mProgressIndicator setMaxValue:(1+4*[images count])];
[mProgressIndicator startAnimation:self];
[enfusetask setDelegate:self];
[enfusetask setProgress:mProgressIndicator]; // needed ?
[NSThread detachNewThreadSelector:@selector(runEnfuse)
						 toTarget:enfusetask
					   withObject:nil];

//[mEnfuseButton setEnabled:NO];
[mEnfuseButton setTitle:@"Cancel"];
return; // testing !				
}

- (void)runEnfuse
{
	// If the task is still sitting around from the last run, release it
	//if (enfuseTask!=nil)
			 //  [enfuseTask release];
			 // Let's allocate memory for and initialize a new TaskWrapper object, passing
			 // in ourselves as the controller for this TaskWrapper object, the path
			 // to the command-line tool, and the contents of the text field that
			 // displays what the user wants to search on
	NSMutableArray *args = [NSMutableArray array];
	
	NSString *filename = @""; // TODO [[mInputFile stringValue] lastPathComponent];
							  //NSString *extension = [[filename pathExtension] lowercaseString];
							  //NSLog(filename);
	NSString* outputfile;
	
	switch ([[mOutputType selectedCell] tag]) {
		case 0 : /* absolute */
			outputfile = [ [useroptions valueForKey:@"exportDirectory"]  /*[mOuputFile stringValue]*/
					 stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:[mOutFile stringValue]
																							 withFormat:"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
																							  appending:[mAppendTo stringValue] ]];
				break;
											 case 1: /* append */
				outputfile = [[useroptions valueForKey:@"exportDirectory"] /*[mOuputFile stringValue]*/
						stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:filename
																								withFormat:@"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
																								 appending:[mAppendTo stringValue] ]];
					break;
											   default:
												   NSLog(@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
	}

[self setOutputfile:outputfile];
[self setTempfile:[[NSFileManager defaultManager] tempfilename:"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/]];
NSLog(@"files are : (%@) %@,%@",outputfile,[self outputfile],[self tempfile]);

#ifndef GNUSTEP
NSString *path = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] bundlePath],
	@"/enfuse/enfuse"];
//[[ NSBundle mainBundle ] pathForAuxiliaryExecutable: @"greycstoration"];
//NSLog(@"path is %@ -> %@",path,[[ NSBundle mainBundle ] bundlePath]);
//[args addObject:[ [ NSBundle mainBundle ] pathForAuxiliaryExecutable: @"greycstoration" ]];
[args addObject:path];
//[args addObject:@"/Users/vbr/Source/CImg-1.2.9/examples/greycstoration"];
// NSString *pathToFfmpeg = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/ffmpeg"];
#else
[args addObject:@"./enfuse"];
#endif
// for debug ? [args addObject:@"-v"]; // be a little bit verbose ?

//[args addObject:@"greycstoration"];
NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//NSLog(@"icc : %@",[defaults boolForKey:@"useCIECAM02"]);
if ([defaults boolForKey:@"useCIECAM"]) { // ICC profile
										  //NSLog(@"%s use ICC !",__PRETTY_FUNCTION__);
	[args addObject:@"-c"];
}

NSString *cachesize = [defaults stringForKey:@"cachesize"];
if (![cachesize isEqualToString:@"default" ]) {
	[args addObject:@"-m"];
	[args addObject:cachesize];
}
NSString *blocksize = [defaults stringForKey:@"blocksize"];
if (![blocksize isEqualToString:@"default" ]) {
	[args addObject:@"-b"];
	[args addObject:blocksize];
}

[args addObject:@"-o"];
[args addObject:[self tempfile]];

//[args addObject:@"-restore"];	
//[args addObject:[mInputFile stringValue]];
NSDictionary* obj=nil;
NSEnumerator *enumerator = [images objectEnumerator];

while ( nil != (obj = [enumerator nextObject]) ) {
	if ([[obj valueForKey:@"enable"] boolValue]){
		//NSLog(@"add enable : %@",[obj valueForKey:@"text"]);
		[args addObject:[obj valueForKey:@"file"]]; // TODO : better !
	}
}

#if 0
//NSLog(@"info jpeg : %@",[mOutQuality stringValue]);
if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"JPEG"] ) {
	[args addObject:[NSString stringWithFormat:@"--compression=%@",[mOutQuality stringValue]]];
} else if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"TIFF"] ) {
	[args addObject:@"--compression=LZW"]; // if jpeg !
}
#else
[args addObject:@"--compression=LZW"]; // if jpeg !
#endif

[args addObject:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];
[args addObject:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
[args addObject:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];

[args addObject:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
[args addObject:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];

[mProgressIndicator setDoubleValue:0.0];
[mProgressIndicator setMaxValue:(1+4*[images count])];

//enfuseTask=[[TaskWrapper alloc] initWithController:self arguments:args];
// kick off the process asynchronously
//[enfuseTask startProcess];
}


#if 0
NSString *outputfile = NSHomeDirectory();
outputfile = [outputfile stringByAppendingPathComponent:@"Pictures"];
NSString *tempString = [[NSProcessInfo processInfo] globallyUniqueString];
outputfile = [outputfile stringByAppendingPathComponent:tempString];
[self setOutputfile:[NSString stringWithFormat:@"%@.%@",outputfile,@"tiff"]]; // TODO




NSLog(@"%s check edit count :%d",__PRETTY_FUNCTION__,[[_editManager editableVersionIds]  count] );
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

#endif

#pragma mark -
#pragma mark TaskWrapper

- (BOOL)shouldContinueOperationWithProgressInfo:(TaskProgressInfo*)inProgressInfo;
{
	//NSLog(@"%s thread is : %@",__PRETTY_FUNCTION__,[NSThread currentThread]);
	//NSLog(@"%s text is : %@",__PRETTY_FUNCTION__,[inProgressInfo displayText]);
	[mProgressText setStringValue:[inProgressInfo displayText]];
	[mProgressIndicator setDoubleValue:[[inProgressInfo progressValue] doubleValue]];
	
	// TODO : should check !
	[inProgressInfo setContinueOperation:findRunning];
	return findRunning;
}

//
// delegate for align_task thread
-(void)alignFinish:(int)status;
{
	NSLog(@"%s status %d",__PRETTY_FUNCTION__,status);
	[mProgressIndicator setDoubleValue:0];
	[mProgressIndicator stopAnimation:self];
	[mProgressText setStringValue:@""];
	int canceled = [aligntask cancel];
	//[aligntask release];
	//aligntask = nil;
	if (status == 0 && canceled != YES) {
		[self doEnfuse];
	} else {
		[mEnfuseButton setTitle:@"Enfuse"];
		// [mEnfuseButton setEnabled:YES];
	}
}

//
// delegate for enfuse task thread 
-(void)enfuseFinish:(int)status;
{
	NSLog(@"%s status %d",__PRETTY_FUNCTION__,status);
	[mProgressIndicator stopAnimation:self];
	[mProgressIndicator setDoubleValue:0];
	[mProgressText setStringValue:@""];
	
    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    //[mEnfuseButton setEnabled:YES];
	int canceled = [enfusetask cancel];
	if (status  == 0 && canceled != YES) {
		if([mCopyMeta state]==NSOnState)  {
			[mProgressText setStringValue:@"Copying Exif values..."];
			[self copyExifFrom:[[images objectAtIndex:0] valueForKey:@"file"] 
							to:[self outputfile] with:[enfusetask outputfile]];
		} else {
			NSFileManager *fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:([enfusetask outputfile])]){
				BOOL result = [fm movePath:[enfusetask outputfile] toPath:[self outputfile] handler:self];
			} else {
				NSString *alert;
				NSString *file = [enfusetask outputfile];
				if (file != nil)
					alert = [file stringByAppendingString: @" do not exist!\nCan't rename"];
				else
					alert = @"no file name !";
				NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
			}
		}
		
		//not used [self openFile:[self outputfile]];
	}
	[mProgressText setStringValue:@""];
	[mEnfuseButton setTitle:@"Enfuse"];
	//[mEnfuseButton setEnabled:YES];
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

-(NSString*)tempfile;
{
	return _tmpfile;
}

-(void)setTempfile:(NSString *)file;
{
	if (_tmpfile != file) {
		[_tmpfile release];
        _tmpfile = [file copy];
	}
}

-(NSString*)temppath;
{
	return _tmppath;
}

-(void)setTempPath:(NSString *)file;
{
	if (_tmppath != file) {
		[_tmppath release];
        _tmppath = [file copy];
	}
}

@end

@implementation enfuseEdit (Private)

-(NSString *)initTempDirectory;
{
	// Create our temporary directory
	NSString* tempDirectoryPath = [NSString stringWithFormat:@"%@/enfuseEdiI", 
		NSTemporaryDirectory()];
	
	// If it doesn't exist, create it
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory;
	if (![fileManager fileExistsAtPath:tempDirectoryPath isDirectory:&isDirectory])
	{
		[fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
	}
	else if (isDirectory) // If a folder already exists, empty it.
	{
		NSArray *contents = [fileManager directoryContentsAtPath:tempDirectoryPath];
		int i;
		for (i = 0; i < [contents count]; i++)
		{
			NSString *tempFilePath = [NSString stringWithFormat:@"%@/%@", 
				tempDirectoryPath, [contents objectAtIndex:i]];
			[fileManager removeFileAtPath:tempFilePath handler:nil];
		}
	}
	else // Delete the old file and create a new directory
	{
		[fileManager removeFileAtPath:tempDirectoryPath handler:nil];
		[fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
	}
	return tempDirectoryPath;
}

// write back the defaults ...
// TODO
-(void)setDefaults;
{ 
#if 0
	[_editManager setUserDefaultsValue:[mOuputFile stringValue] forKey@"outputDirectory"];
	
	[_editManager setUserDefaultsValue:[mOutFile stringValue] forKey:@"outputFile"];
	[_editManager setUserDefaultsValue:[mAppendTo stringValue] forKey:@"outputAppendTo"];
	[_editManager setUserDefaultsValue:[mOutQuality stringValue] forKey:@"outputQuality"];
#endif      
	id obj = [useroptions valueForKey:@"importInAperture"];
	if (obj != nil)
		[_editManager setUserDefaultsValue:obj
									forKey:@"importInAperture"];
	
	obj = [useroptions valueForKey:@"stackWithOriginal"];
	if (obj != nil)
		[_editManager setUserDefaultsValue:obj
									forKey:@"stackWithOriginal"];
	
	obj = [useroptions valueForKey:@"addKeyword"];
	if (obj != nil) {
		[_editManager setUserDefaultsValue:obj
									forKey:@"addKeyword"];
		if ([obj boolValue])
			[_editManager setUserDefaultsValue:[useroptions valueForKey:@"keyword"]
										forKey:@"keyword"];
		
	} 
	
}

// read back the defaults ...
// TODO
-(void)getDefaults;
{
#if 0
	
	[mOuputFile setStringValue:[_editManager userDefaultsObjectForKey:@"outputDirectory"]];
	[mOutFile setStringValue:[_editManager userDefaultsObjectForKey:@"outputFile"]];
	[mAppendTo setStringValue:[_editManager userDefaultsObjectForKey:@"outputAppendTo"]];
	[mOutQuality setStringValue:[_editManager userDefaultsObjectForKey:@"outputQuality"]];
#endif
}

-(void)cleanuptempdir;
{
	NSFileManager *defaultManager = [NSFileManager defaultManager];
	NSLog(@"%s",__PRETTY_FUNCTION__);
	//NSData* data = [self dataOfType:@"xml"];
	//[data writeToFile:@"/tmp/test.xml" atomically:YES ];
	NSDictionary* obj=nil;
	NSEnumerator *enumerator = [images objectEnumerator];
	
	while ( nil != (obj = [enumerator nextObject]) ) {
		//NSLog(@"removing : %@",[obj valueForKey:@"thumbfile"]);		
		[defaultManager removeFileAtPath:[obj valueForKey:@"thumbfile"] handler:self];
	}	
	NSString *filename;
	enumerator = [[defaultManager directoryContentsAtPath: [self temppath] ] objectEnumerator];
	while (nil != (filename = [enumerator nextObject]) ) {
		//NSLog(@"file : %@",[filename lastPathComponent]);
		if ([[filename lastPathComponent] hasPrefix:@"align"]) {				
			[defaultManager removeFileAtPath:[NSString stringWithFormat:@"%@/%@",[self temppath],filename] handler:self];
		}
	}
	
}

@end
