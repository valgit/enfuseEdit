//
//	enfuseEdit.m
//	enfuseEdit
//
//	Created by valery brasseur on 28/09/08.
//	Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "enfuseEdit.h"
#import "MLog.h"

#import "NSFileManager-Extensions.h"
#import "TaskProgressInfo.h"

// Categories : private methods
@interface enfuseEdit (Private)

-(void)setDefaults;
-(void)getDefaults;

-(NSString *)initTempDirectory;
-(void)cleanuptempdir;

-(BOOL)checkApplicationPath;

// handle Exif
-(void)copyExif;

// handle presets 
- (NSData *) dataOfType: (NSString *) typeName;
- (BOOL) readFromData: (NSData *) data ofType: (NSString *) typeName;

-(NSString*)previewfilename:(NSString *)file;
-(void)buildPreview;
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
    if (self = [super init]) {
        _apiManager = apiManager;
        _editManager = [[_apiManager apiForProtocol:@protocol(ApertureEditManager)] retain];
        if (!_editManager)
            return nil;

        // Finish your initialization here
        MLogString(6 ,@"");
        // Create the array we'll use to hold the paths to our images
        //test images = [[NSMutableArray alloc] init];
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
    //test [images release];

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

// when first launched, this routine is called when all objects are created
// and initialized.  It's a chance for us to set things up before the user gets
// control of the UI.
-(void)awakeFromNib
{
    MLogString(6 ,@"");

#if 1
	NSDate *expirationDate = 
	[[NSDate dateWithNaturalLanguageString:
			[NSString stringWithCString:__DATE__]] 
            addTimeInterval:(60*60*24*30/*30 days*/)];
	
    if( [expirationDate earlierDate:[NSDate date]] 
		== expirationDate )
    {
        int result = NSRunAlertPanel(@"Beta Expired", 
									 @"This beta has expired, please visit "
									 "http://vald70.free.fr/ to grab"
									 "the latest version.", 
									 @"Take Me There", @"Exit", nil);
		
        if( result == NSAlertDefaultReturn )
        {
            [[NSWorkspace sharedWorkspace] openURL:
				[NSURL URLWithString:
							  @"http://vald70.free.fr/"]];
        }
        [[NSApplication sharedApplication] terminate:self];
    }
#endif
	
    findRunning=NO;

    [_editWindow center];
    //	[window makeKeyAndOrderFront:nil];

    // this allows us to declare which type of pasteboard types we support
    //[mTableImage setDataSource:self];
    [mTableImage setRowHeight:128];               // have some place ...

    // theIconColumn = [table tableColumnWithIdentifier:@"icon"];
    // [ic setImageScaling:NSScaleProportionally]; // or NSScaleToFit
    [self reset:_revertButton];
	
}

#pragma mark -
// UI Methods
#pragma mark UI Methods

- (NSWindow *)editWindow
{
    MLogString(6 ,@"");
    if (_editWindow == nil) {
        NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
        NSNib *myNib = [[NSNib alloc] initWithNibNamed:@"enfuseEdit" bundle:myBundle];
        if ([myNib instantiateNibWithOwner:self topLevelObjects:&_topLevelNibObjects]) {
            [_topLevelNibObjects retain];
        }
        [myNib release];

		BOOL pathok = [self checkApplicationPath];
		if (!pathok) {
			 NSRunAlertPanel (NSLocalizedString(@"Installation Error",@""),
						@"", NSLocalizedString(@"OK",nil), NULL, NULL);
			[self cleanuptempdir];

			[_editManager endEditSession];
		}
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
    for (index=0; index < count; index++) {
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
	[self getDefaults];
}

- (void)editManager:(id<ApertureEditManager>)editManager didImportImageAtPath:(NSString *)path versionUniqueID:(NSString *)versionUniqueID
{
    MLogString(6 ,@"");
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
    MLogString(6 ,@"");
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
    MLogString(6 ,@"");
    if (findRunning) {
        NSRunAlertPanel (NSLocalizedString(@"Already Running task Error",@""),
            NSLocalizedString(@"NYI",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
    }
    // maybe we should to some cleanup ?
    //- (void)deleteVersions:(NSArray *)versionUniqueIDs;

    [self cleanuptempdir];

	// if enfuse as run, delete the results ...
	if ([[NSFileManager defaultManager] fileExistsAtPath:[self outputfile]]) {
		[[NSFileManager defaultManager] removeFileAtPath:[self outputfile] handler:self];
	}
	
    // Tell Aperture to cancel
    [_editManager cancelEditSession];
}

- (IBAction)_doneEditing:(id)sender
{
    MLogString(6 ,@"");
	
    if (findRunning) {
        NSRunAlertPanel (NSLocalizedString(@"Already Running task Error",@""),
						 NSLocalizedString(@"NYI",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
    }
	
    // maybe we should to some cleanup ?
    //- (void)deleteVersions:(NSArray *)versionUniqueIDs;
	
    if ([[useroptions valueForKey:@"importInAperture"] boolValue]) {
        MLogString(6 ,@"should import");
		
		if ([_editManager canImport]) {
			MLogString(6 ,@"will import");
			if ([[useroptions valueForKey:@"stackWithOriginal"] boolValue]) {
				//NSString *enfuseImage= @"/Users/valery/Pictures/working/test.tiff"; // TODO
				// should we check for referenced ?
				[_editManager importImageAtPath:[self outputfile] referenced:YES stackWithVersions:[_editManager selectedVersionIds]];
				// - (id)importedVersionIds;
			} else {
				MLogString(6, @"will import, not stacked");
				[_editManager importImageAtPath:[self outputfile] referenced:YES stackWithVersions:nil];
			}
			
		}
		else {
			MLogString(6 ,@"can't import but import required !");
			[self cleanuptempdir];
			
			// should we display something here ?
			[_editManager endEditSession];
		}
	} else {
		NSLog(@"%s no import !");
		[self cleanuptempdir];
		
		// should we display something here ?
		[_editManager endEditSession];		
	}
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
        //MLogString(1,@"as cache data for %d",index);
        return cachedata;
    }

    NSString *_versionID;
    NSImage* image;
    NSString *text;
	NSString *thumbname;
    NSNumber *enable = [NSNumber numberWithBool: YES];
    MLogString(1,@"data for: %d",index);
    //NSMutableDictionary *dict = [images objectAtIndex:index];
    //NSLog(@"dict : %@",[dict objectForKey:@"thumb"]);
    // TODO : better check for null ...
    //    Get the ID for the selected version
    _versionID = [[[_editManager selectedVersionIds] objectAtIndex:index] retain];

    // Get properties ...
    NSDictionary *properties = [_editManager propertiesWithoutThumbnailForVersion:_versionID];
    //NSLog(@"%s : props are %@", __PRETTY_FUNCTION__, properties);
    //no valuated NSString *path = [_editManager pathOfEditableFileForVersion:_versionID];
	// get the Aperture "name"
	NSString *exportName = [[[properties objectForKey:kExportKeyVersionName] retain ] autorelease];
	MLogString(1,@"export name : %@",exportName);
	
	//    Get the thumbnail from Aperture
    image = [[_editManager thumbnailForVersion:_versionID size:kExportThumbnailSizeThumbnail] retain];
	thumbname = [self previewfilename:exportName];
    //image = nil;
    if ( nil == image) {
        MLogString(6,@"can't get thumbnail");
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSString *noThumbPath = [bundle pathForResource:@"image_broken" ofType:@"png" inDirectory:nil];
		NSImage *nothumb = [[[NSImage alloc] initWithContentsOfFile:noThumbPath] autorelease];
		image = nothumb;
    } else {
		NSData *thumbData = [image  TIFFRepresentation];
		[thumbData writeToFile:thumbname atomically:YES];
	}
	
    NSDictionary *exif = [properties objectForKey:kExportKeyEXIFProperties];
    //NSLog(@"%s : exif are %@", __PRETTY_FUNCTION__, exif);
    if(exif) {                                    /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
        NSString *focalLengthStr, *fNumberStr, *exposureTimeStr,*exposureBiasStr;
        //NSLog(@"the exif data is: %@", [exif description]);
        NSNumber *focalLengthObj = [exif objectForKey:(NSString *)kCGImagePropertyExifFocalLength];
        if (focalLengthObj) {
            focalLengthStr = [NSString stringWithFormat:@"Focal Length: %@mm", [focalLengthObj stringValue]];
        } else focalLengthStr = @"";
        NSNumber *fNumberObj = [exif objectForKey:(NSString *)kCGImagePropertyExifApertureValue /* kCGImagePropertyExifFNumber */ ];
        if (fNumberObj) {
            fNumberStr = [NSString stringWithFormat:@"Aperture: F%@", [fNumberObj stringValue]];
        } else fNumberStr = @"--";
        NSNumber *exposureTimeObj = (NSNumber *)[exif objectForKey:@"ShutterSpeed" /* (NSString *)kCGImagePropertyExifExposureTime*/];
        //NSLog(@"%s : exif speed %@", __PRETTY_FUNCTION__, exposureTimeObj);  /* ShutterSpeed */
		if (exposureTimeObj) {
			if ([exposureTimeObj floatValue] < 1.0)
				exposureTimeStr = [NSString stringWithFormat:@"Shutter Speed : 1/%.1f s", (1. / [exposureTimeObj floatValue])];
			else
				exposureTimeStr = [NSString stringWithFormat:@"Shutter Speed : %.1f s", ([exposureTimeObj floatValue])];
        } else exposureTimeStr = @"--";
        NSNumber *exposureBiasObj = (NSNumber *)[exif objectForKey:@"ExposureBiasValue" /* (NSString *)kCGImagePropertyExifExposureBiasValue*/]; /* ExposureBiasValue */
        //NSLog(@"%s : exif bias %@", __PRETTY_FUNCTION__, exposureBiasObj);
		if (exposureBiasObj) {
            exposureBiasStr = [NSString stringWithFormat:@"Exposure Comp. : %+0.1f EV", [exposureBiasObj floatValue]];
        } else exposureBiasStr = @"--";

        text = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@", exportName,
            focalLengthStr,exposureTimeStr,fNumberStr, exposureBiasStr];
    }                                             /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
    /* kCGImagePropertyExifApertureValue kCGImagePropertyExifShutterSpeedValue */
    else {
        text = [NSString stringWithFormat:@"%@\n no exif", exportName];
    }

    // text = [NSString stringWithFormat:@"%@ %@",exportName,path];

    cachedata = [NSMutableDictionary dictionaryWithObjectsAndKeys:enable,@"enable",text,@"text",image,@"thumb",exportName,@"file",thumbname,@"thumbfile",nil];
    [_cacheImagesInfos setValue:cachedata forKey:indexkey];
    //NSLog(@"%s cache size is %d",__PRETTY_FUNCTION__,[_cacheImagesInfos count]);
    return cachedata;
}

//
-(void)insertObject:(id)obj inImagesAtIndex:(unsigned)index;
{
	MLogString(6 ,@"obj is : %@",obj);
    //test [images insertObject: obj  atIndex: index];
}

-(void)removeObjectFromImagesAtIndex:(unsigned)index;
{
    MLogString(6 ,@"");
    //test [images removeObjectAtIndex: index];
}

-(void)replaceObjectInImagesAtIndex:(unsigned)index withObject:(id)obj;
{
   MLogString(6 ,@"");
    //test [images replaceObjectAtIndex: index withObject: obj];
}

#pragma mark -
#pragma mark Action GUI

- (IBAction)reset:(id)sender
{
    MLogString(6 ,@"");

    [mContrastSlider setFloatValue:0.0];          // (0 <= WEIGHT <= 1).  Default: 0
    [self takeContrast:mContrastSlider];

    [mExposureSlider setFloatValue:1.0];          // 0 <= WEIGHT <= 1).  Default: 1
    [self takeExposure:mExposureSlider];

    [mSaturationSlider setFloatValue:0.2];        // (0 <= WEIGHT <= 1).  Default: 0.2
    [self takeSaturation:mSaturationSlider];

    [mMuSlider setFloatValue:0.5];                // mu (0 <= MEAN <= 1).  Default: 0.5
    [self takeMu:mMuSlider];

    [mSigmaSlider setFloatValue:0.2];             // sigma (SIGMA > 0).  Default: 0.2
    [self takeSigma:mSigmaSlider];
	
}

- (IBAction) runPreview: (id)sender;
{
    MLogString(6 ,@"");
	// right place ??
	[self buildPreview];
}

- (IBAction) about: (id)sender;
{
    MLogString(6 ,@"");
    #if 0
    // Method to load the .nib file for the info panel.
    if (!infoPanel) {
        if (![NSBundle loadNibNamed:@"InfoPanel" owner:self]) {
            NSLog(@"Failed to load InfoPanel.nib");
            NSBeep();
            return;
        }
        [infoPanel center];
    }
    [infoPanel makeKeyAndOrderFront:nil];
    #endif

	BOOL openResult;
	openResult = [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://vald70.free.fr/" ] ];
}

#if 0
//  test for detecting end of sliding ...
//
- (IBAction)takeSaturation:(id)sender {
	//MLogString(6 ,@"");
	
    SEL trackingEndedSelector = @selector(SaturationsliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0
		inModes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
	
    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mSaturationTextField setFloatValue:theValue];
	[mSaturationSlider setFloatValue:theValue];
	
}

- (void)SaturationsliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

- (IBAction)takeContrast:(id)sender {
	//MLogString(6 ,@"");
	
    SEL trackingEndedSelector = @selector(ContrastsliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0];
	
    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mContrastTextField setFloatValue:theValue];
	[mContrastSlider setFloatValue:theValue];	
}

- (void)ContrastsliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

- (IBAction)takeExposure:(id)sender {
	MLogString(6 ,@"");
	
    SEL trackingEndedSelector = @selector(ExposuresliderEnded:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self
											 selector:trackingEndedSelector object:sender];
    [self performSelector:trackingEndedSelector withObject:sender afterDelay:0.0];
	
    // do whatever you want to do during tracking here 
	float theValue = [sender floatValue];
	[mExposureTextField setFloatValue:theValue];
	[mExposureSlider setFloatValue:theValue];
}

- (void)ExposuresliderEnded:(id)sender 
{
	MLogString(6 ,@"");
    // do whatever you want to do when tracking ends here 
    // call preview ?
	[self buildPreview];
}

#else
// normal way ...
//

- (IBAction) takeSaturation: (id)sender;
{
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    float theValue = [sender floatValue];
    [mSaturationTextField setFloatValue:theValue];
    [mSaturationStepper setFloatValue:theValue];
    [mSaturationSlider setFloatValue:theValue];
}

- (IBAction) takeContrast: (id)sender;
{
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    float theValue = [sender floatValue];
    [mContrastTextField setFloatValue:theValue];
    [mContrastStepper setFloatValue:theValue];
    [mContrastSlider setFloatValue:theValue];
}

- (IBAction) takeExposure: (id)sender;
{
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    float theValue = [sender floatValue];
    [mExposureTextField setFloatValue:theValue];
    [mExposureStepper setFloatValue:theValue];
    [mExposureSlider setFloatValue:theValue];
}

#endif

- (IBAction) takeSigma: (id)sender;
{
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    float theValue = [sender floatValue];
    [mSigmaTextField setFloatValue:theValue];
    [mSigmaStepper setFloatValue:theValue];
    [mSigmaSlider setFloatValue:theValue];
}

- (IBAction) takeMu: (id)sender;
{
    //NSLog(@"%s",__PRETTY_FUNCTION__);
    float theValue = [sender floatValue];
    [mMuTextField setFloatValue:theValue];
    [mMuStepper setFloatValue:theValue];
    [mMuSlider setFloatValue:theValue];
}

- (IBAction) openPresets: (id)sender;
{
    // - (id)userDefaultsObjectForKey:(NSString *)key;

    MLogString(6 ,@"");
    NSOpenPanel *open = [NSOpenPanel openPanel];
    [open setTitle:@"Load Presets"];
    [open setAllowsMultipleSelection:NO];
    if([open runModalForTypes:[NSArray arrayWithObject:@"enf"]] == NSOKButton) {
        NSString *file = [[open filenames] objectAtIndex:0];

        NSData *data = [NSData dataWithContentsOfFile:file];
        [self readFromData:data ofType:@"xml"];
        [data release];
    }
}

- (IBAction) savePresets: (id)sender;
{
    // - (void)setUserDefaultsValue:(id)value forKey:(NSString *)key;

    MLogString(6 ,@"");
    NSSavePanel *save = [NSSavePanel savePanel];
    [save setTitle:@"Save Presets"];
    [save setRequiredFileType:@"enf"];
    if([save runModal] == NSOKButton) {
        NSString *file = [save filename];

        NSData* data = [self dataOfType:@"xml"];
        [data writeToFile:file atomically:YES ];
        [data release];
    }
}

- (IBAction)preferencesSaving:(id)sender;
{
    MLogString(6 ,@"");

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
    MLogString(6 ,@"");

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

- (IBAction)cancel:(id)sender
{
	MLogString(6 ,@"");
	//[ NSApp stopModal ];
	findRunning = NO;
}

- (IBAction) enfuse: (id)sender;
{
    MLogString(6 ,@"");
    if (findRunning) {
        MLogString(6,@"already running");
        //NSRunAlertPanel (NSLocalizedString(@"Error",@""),
        //				 NSLocalizedString(@"Process already running",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
        findRunning = NO;
        return;
    }
    else {
		if (![self checkApplicationPath]) {
			NSRunAlertPanel (NSLocalizedString(@"Error",@""),
        				 NSLocalizedString(@"Installation Error",nil), NSLocalizedString(@"OK",nil), NULL, NULL);
			return;
		}
        findRunning = YES;
        if (aligntask != nil) {
            MLogString(4,@"need to cleanup autoalign ?");
            [aligntask release];
            aligntask = nil;
        }

        if ([mAutoAlign state] == NSOnState) {
			// prepare progress sheet
			[ NSApp beginSheet: mProgressPanel 
				modalForWindow: [_editManager apertureWindow] modalDelegate: nil
				didEndSelector: nil contextInfo: nil ];
			
            MLogString(4,@"need to autoalign");
            aligntask = [[alignStackTask alloc] initWithPath:[self temppath]];
            [aligntask setGridSize:[mGridSize stringValue]];
            [aligntask setControlPoints:[mControlPoints stringValue]];

            MLogString(4,@"check edit count :%d",[[_editManager editableVersionIds]  count] );
            //int i, count = [[_editManager selectedVersionIds] count];
            //NSLog(@"%s adding selected : %d",__PRETTY_FUNCTION__,count);
            // Tell Aperture to make an editable version of these images. If this version is already editable, this method won't generate a new version
            // but will still return the appropriate properties.
            // format ? requestedFormat:kApertureImageFormatTIFF8
            NSArray *properties = [_editManager editableVersionsOfVersions:[_editManager selectedVersionIds] stackWithOriginal:YES];
            //NSLog(@"%s editables propos are : << %@ >>",__PRETTY_FUNCTION__,properties);

            int i, count = [[_editManager editableVersionIds]  count];
            MLogString(4,@"edit count :%d",count );

            for (i = 0; i < count; i++) {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                // if ([[obj valueForKey:@"enable"] boolValue]){

                //NSDictionary *imageProperties = [properties objectAtIndex:0];
                //    Get the path to the editable version
                NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:i];
                MLogString(4,@"edit %@",editableVersionId);
                NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
                [aligntask addFile:imagePath];
                //NSLog(@"%s : %@ %@ %@ %@",__PRETTY_FUNCTION__,
                //	versionID,editableVersionId,imagePath,path);
                [pool release];
            }

            [mProgressIndicator setUsesThreadedAnimation:YES];
            //[mProgressIndicator setIndeterminate:YES];
            [mProgressIndicator setDoubleValue:0.0];
                                                  // TOTO : add enfuse step ?
            [mProgressIndicator setMaxValue:(1+23* [self countOfImages] )];
            [mProgressIndicator startAnimation:self];
            [mProgressText setStringValue:@"Aligning..."];
            [aligntask setDelegate:self];
                                                  // needed ?
            [aligntask setProgress:mProgressIndicator];
            [NSThread detachNewThreadSelector:@selector(runAlign)
                toTarget:aligntask
                withObject:nil];
            //[mProgressIndicator stopAnimation:self];
            //[mProgressIndicator setIndeterminate:NO];
            // for now !
            //[mEnfuseButton setEnabled:NO];
			
			// show the progress sheet		
			[ NSApp runModalForWindow: mProgressPanel ];
			[ NSApp endSheet: mProgressPanel ];
			[ mProgressPanel orderOut: self ];
			
            //[mEnfuseButton setTitle:@"Cancel"];
            return;                               // testing !
        }
        else {
            MLogString(6,@"need to enfuse");
            [self doEnfuse];
        }

    }
}

- (void)doEnfuse
{
    MLogString(6 ,@"");
    NSDictionary* file=nil;

    //
    // create the output file name  kExportKeyReferencedMasterPath kExportKeyVersionName
    //
    NSString *filename;
    file = [self objectInImagesAtIndex:0];
    if (file != nil) {
        filename = [[file valueForKey:@"file"] lastPathComponent ];
    }
    else {
        filename = @"enfused";
    }
								
    // TODO [[mInputFile stringValue] lastPathComponent];
    //NSString *extension = [[filename pathExtension] lowercaseString];
    //NSLog(filename);
    NSString* outputfile;
	//MLogString(1,@"export dir will be set to : %@",[useroptions valueForKey:@"exportDirectory"]);
	
    switch ([[mOutputType selectedCell] tag]) {
        case 0 :                                  /* absolute */
                                                  /*[mOuputFile stringValue]*/
            outputfile = [ [useroptions valueForKey:@"exportDirectory"]
                stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:[mOutFile stringValue]
                withFormat:@"tiff"                /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
                appending:[mAppendTo stringValue] ]];
            break;
        case 1:                                   /* append */
                                                  /*[mOuputFile stringValue]*/
            outputfile = [ [useroptions valueForKey:@"exportDirectory"]
                stringByAppendingPathComponent:[[NSFileManager defaultManager] nextUniqueNameUsing:filename
                withFormat:@"tiff"                /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/
                appending:[mAppendTo stringValue] ]];
            break;
        default:
            MLogString(1,@"bad selected tag is %d",[[mOutputType selectedCell] tag]);
    }
	
	//MLogString(1,@"output will be set to : %@",outputfile);
    [self setOutputfile:outputfile];
	//MLogString(1,@"output is set to : %@",[self outputfile]);
	
    //
    // create the enfuse task
    if (enfusetask != nil) {
        MLogString(2,@"need to enfuse task");
        [enfusetask release];
        enfusetask = nil;
    }

    enfusetask = [[enfuseTask alloc] init];

    // temporary file for output
	[self setTempfile:[[NSFileManager defaultManager] tempfilename:@"tiff" /*[[mOutFormat titleOfSelectedItem] lowercaseString]*/]];
    [enfusetask setOutputfile:[self tempfile]];

    // TODO : check if align_image was run ...
    if ([mAutoAlign state] == NSOnState) {
        MLogString(2,@"autoalign was run, get align data");
        // put filenames and full pathnames into the file array
        NSEnumerator *enumerator = [[[NSFileManager defaultManager] directoryContentsAtPath: [self temppath] ] objectEnumerator];
        while (nil != (filename = [enumerator nextObject])) {
            //NSLog(@"file : %@",[filename lastPathComponent]);
            if ([[filename lastPathComponent] hasPrefix:@"align"]) {
                [enfusetask addFile:[NSString stringWithFormat:@"%@/%@",[self temppath],filename]];
            }
        }

    }
    else {

        NSLog(@"%s check edit count :%d",__PRETTY_FUNCTION__,[[_editManager editableVersionIds]  count] );
        //int i, count = [[_editManager selectedVersionIds] count];
        //NSLog(@"%s adding selected : %d",__PRETTY_FUNCTION__,count);
        // Tell Aperture to make an editable version of these images. If this version is already editable, this method won't generate a new version
        // but will still return the appropriate properties.
        // format ? requestedFormat:kApertureImageFormatTIFF8
        NSArray *properties = [_editManager editableVersionsOfVersions:[_editManager selectedVersionIds] stackWithOriginal:YES];
        //NSLog(@"%s editables propos are : << %@ >>",__PRETTY_FUNCTION__,properties);

        int i, count = [[_editManager editableVersionIds]  count];
        MLogString(4,@"edit count :%d",count );

        for (i = 0; i < count; i++) {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            // if ([[obj valueForKey:@"enable"] boolValue]){

            //NSDictionary *imageProperties = [properties objectAtIndex:0];
            //    Get the path to the editable version
            NSString *editableVersionId = [[_editManager editableVersionIds] objectAtIndex:i];
            MLogString(4,@"edit %@",editableVersionId);
            NSString *imagePath = [_editManager pathOfEditableFileForVersion:editableVersionId];
            [enfusetask addFile:imagePath];
            //NSLog(@"%s : %@ %@ %@ %@",__PRETTY_FUNCTION__,
            //	versionID,editableVersionId,imagePath,path);
            [pool release];
        }
    }

	// prepare progres sheet
	[ NSApp beginSheet: mProgressPanel 
		modalForWindow: [_editManager apertureWindow] modalDelegate: nil
		didEndSelector: nil contextInfo: nil ];
	[mProgressText setStringValue:@"Setting up Enfusing..."];
	
    #if 0
    // TODO : check the preferences ...
    if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"JPEG"] ) {
        [enfusetask addArg:[NSString stringWithFormat:@"--compression=%@",[mOutQuality stringValue]]];
    }
    else if ([[mOutFormat titleOfSelectedItem] isEqualToString:@"TIFF"] ) {
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
    [mProgressIndicator setMaxValue:(1+4*[self countOfImages])];
    [mProgressIndicator startAnimation:self];
    [enfusetask setDelegate:self];
    [enfusetask setProgress:mProgressIndicator];  // needed ?
    [NSThread detachNewThreadSelector:@selector(runEnfuse)
        toTarget:enfusetask
        withObject:nil];

    //[mEnfuseButton setEnabled:NO];
	
	// show the progress sheet
	[ NSApp runModalForWindow: mProgressPanel ];
	[ NSApp endSheet: mProgressPanel ];
	[ mProgressPanel orderOut: self ];
				
	   //[mEnfuseButton setTitle:@"Cancel"];
    return;                                       // testing !
}


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
    MLogString(5,@"status %d",status);
    [mProgressIndicator setDoubleValue:0];
    [mProgressIndicator stopAnimation:self];
    [mProgressText setStringValue:@""];
    int canceled = [aligntask cancel];
    //[aligntask release];
    //aligntask = nil;
    if (status == 0 && canceled != YES) {
        [self doEnfuse];
    }
    else {
        [mEnfuseButton setTitle:@"Enfuse"];
        // [mEnfuseButton setEnabled:YES];
    }
	[ NSApp stopModal ];
}

//
// delegate for enfuse task thread
-(void)enfuseFinish:(int)status;
{
    MLogString(5,@"status %d",status);
    [mProgressIndicator stopAnimation:self];
    [mProgressIndicator setDoubleValue:0];
    [mProgressText setStringValue:@""];

    findRunning=NO;
    // change the button's title back for the next search
    //[mEnfuseButton setTitle:@"Enfuse"];
    //[mEnfuseButton setEnabled:YES];
    int canceled = [enfusetask cancel];
	MLogString(1,@"output will be : %@",[self outputfile]);
    if (status  == 0 && canceled != YES) {
        if([mCopyMeta state]==NSOnState) {
            [mProgressText setStringValue:@"Copying Exif values..."];
			[mProgressIndicator startAnimation:self];
			[mProgressIndicator setIndeterminate:YES];
			// do it on thread !
			[NSThread detachNewThreadSelector:@selector(copyExif)
									 toTarget:self
								   withObject:nil];
			//[self copyExif];
			//[mProgressIndicator stopAnimation:self];
			//[mProgressIndicator setDoubleValue:0];
			return;
		}
        else {
            NSFileManager *fm = [NSFileManager defaultManager];
            if ([fm fileExistsAtPath:([enfusetask outputfile])]) {
                BOOL result = [fm movePath:[enfusetask outputfile] toPath:[self outputfile] handler:self];
				if (!result) {
					NSString *alert;
					NSString *file = [enfusetask outputfile];
					if (file != nil)
						alert = [file stringByAppendingString: @"Can't rename"];
					else
						alert = @"no file name !";
					
						NSRunAlertPanel (NULL, alert , @"OK", NULL, NULL);
				}
            }
            else {
                NSString *alert;
                NSString *file = [enfusetask outputfile];
                if (file != nil)
                    alert = [file stringByAppendingString: @" do not exist!\nCan't rename"];
                else
                    alert = @"no file name !";
                NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
            }
			MLogString(4,@"show preview of : %@",[self outputfile]);
			NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:[self outputfile]] autorelease];
			[mPreviewImage setImage:_image];			
        }

        //not used [self openFile:[self outputfile]];
		    }
    [mProgressText setStringValue:@""];
    [mEnfuseButton setTitle:@"Enfuse"];
    //[mEnfuseButton setEnabled:YES];
	[ NSApp stopModal ];
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
    NSString* tempDirectoryPath = [NSString stringWithFormat:@"%@/enfuseEdit",
        NSTemporaryDirectory()];

    // If it doesn't exist, create it
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:tempDirectoryPath isDirectory:&isDirectory]) {
        [fileManager createDirectoryAtPath:tempDirectoryPath attributes:nil];
    }
    else if (isDirectory) {                       // If a folder already exists, empty it.
        NSArray *contents = [fileManager directoryContentsAtPath:tempDirectoryPath];
        int i;
        for (i = 0; i < [contents count]; i++) {
            NSString *tempFilePath = [NSString stringWithFormat:@"%@/%@",
                tempDirectoryPath, [contents objectAtIndex:i]];
            [fileManager removeFileAtPath:tempFilePath handler:nil];
        }
    }
    else {                                        // Delete the old file and create a new directory
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

		obj = [useroptions valueForKey:@"exportDirectory"];
		if (obj != nil) {
			[_editManager setUserDefaultsValue:obj
										forKey:@"exportDirectory"];
		}
    }

}

// read back the defaults ...
// TODO
-(void)getDefaults;
{
    #if 0
    [mOutFile setStringValue:[_editManager userDefaultsObjectForKey:@"outputFile"]];
    [mAppendTo setStringValue:[_editManager userDefaultsObjectForKey:@"outputAppendTo"]];
    [mOutQuality setStringValue:[_editManager userDefaultsObjectForKey:@"outputQuality"]];
    #endif
	
	[useroptions setValue:[_editManager userDefaultsObjectForKey:@"addKeyword"]
        forKey:@"addKeyword"];
    [useroptions setValue:[_editManager userDefaultsObjectForKey:@"importInAperture"]
        forKey:@"importInAperture"];
    [useroptions setValue:[_editManager userDefaultsObjectForKey:@"stackWithOriginal"]
        forKey:@"stackWithOriginal"];
    if ( [[useroptions valueForKey:@"addKeyword"] boolValue] )
        [useroptions setObject:[_editManager userDefaultsObjectForKey:@"keyword"]
        forKey:@"keyword"];
    else
        [useroptions removeObjectForKey:@"keyword"];
	NSString* export = [_editManager userDefaultsObjectForKey:@"exportDirectory"];
	if (export != nil) {
		[useroptions setValue:export forKey:@"exportDirectory"];
	} else {
        NSString *outputDirectory;
        outputDirectory = NSHomeDirectory();
        outputDirectory = [outputDirectory stringByAppendingPathComponent:@"Pictures"];
        [useroptions setValue:outputDirectory forKey:@"exportDirectory"];
    }
}

-(void)cleanuptempdir;
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    MLogString(6 ,@"");
    
    NSString *filename;
    NSEnumerator* enumerator = [[defaultManager directoryContentsAtPath: [self temppath] ] objectEnumerator];
    
	while (nil != (filename = [enumerator nextObject]) ) {
        //NSLog(@"file : %@",[filename lastPathComponent]);
        if ([[filename lastPathComponent] hasPrefix:@"align"]) {
            [defaultManager removeFileAtPath:[NSString stringWithFormat:@"%@/%@",[self temppath],filename] handler:self];
        }
    }

	// remove tempdir ...
	[defaultManager removeFileAtPath:[self temppath] handler:self];

	if ([defaultManager fileExistsAtPath:[self tempfile]]) {
		[defaultManager removeFileAtPath:[self tempfile] handler:self];
	}
	
	[self setDefaults];
}

-(BOOL)checkApplicationPath;
{
	NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
    
        NSString *path = [NSString stringWithFormat:@"%@%@",[myBundle resourcePath],
            @"/align_image_stack"];
        MLogString(4,@"path is : %@",path);
        // check for enfuse binaries...
        if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO) {
            NSString *alert = [path stringByAppendingString: @" is not executable!"];
            NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
            return NO;
        }

        path = [NSString stringWithFormat:@"%@%@",[myBundle resourcePath],
            @"/enfuse"];
        MLogString(4,@"path is : %@",path);

        // check for enfuse binaries...
        if([[NSFileManager defaultManager] isExecutableFileAtPath:path]==NO) {
            NSString *alert = [path stringByAppendingString: @" is not executable!"];
            NSRunAlertPanel (NULL, alert, @"OK", NULL, NULL);
            return NO;
        }
    return YES;
}

-(void)copyExif;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	//NSMutableDictionary* newExif;
	MLogString(6,@"from:%@ to:%@",[self tempfile],[self outputfile]);
	
#ifndef GNUSTEP
	
	// create the source 
	//NSURL *_url = [NSURL fileURLWithPath:sourcePath]; // for exif
	NSURL *_outurl = [NSURL fileURLWithPath:[self outputfile]]; // dest
	NSURL *_tmpurl = [NSURL fileURLWithPath:[self tempfile]]; // for image
	//CGImageSourceRef exifsrc = CGImageSourceCreateWithURL((CFURLRef)_url, NULL);
	//    Get the ID for the selected version
	NSString *_versionID;
    _versionID = [[[_editManager selectedVersionIds] objectAtIndex:0] retain];

	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)_tmpurl, NULL);
	if(source != nil) {
		// get Exif from source?
		// Get properties ...
		NSDictionary *metadata = [_editManager propertiesWithoutThumbnailForVersion:_versionID];
		
		//NSDictionary* metadata = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(exifsrc, 0, NULL);
		//make the metadata dictionary mutable so we can add properties to it
		NSMutableDictionary *metadataAsMutable = [[metadata mutableCopy]autorelease];
		//crash ? [metadata release];
		
		//NSLog(@"props: %@", [(NSDictionary *)properties description]);
		//NSMutableDictionary *newExif = [[[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary]mutableCopy]autorelease];
		NSMutableDictionary *newExif = [[[metadata objectForKey:(NSString *)kExportKeyEXIFProperties]mutableCopy]autorelease];		
		
		if(!newExif) {
			//if the image does not have an EXIF dictionary (not all images do), then create one for us to use
			newExif = [NSMutableDictionary dictionary];
		}
		
		if(newExif) { /* kCGImagePropertyIPTCDictionary kCGImagePropertyExifAuxDictionary */
			//MLogString(1,@"the exif data is: %@", [newExif description]);
			//newExif = [NSMutableDictionary dictionaryWithDictionary:exif];
			MLogString(2,@"removing bias value");
			[newExif removeObjectForKey:@"ExposureBiasValue"];
			
			if ([mCopyShutter state]==NSOnState) {
				MLogString(2,@"removing shutter speed");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifExposureTime];
			}
			if ([mCopyAperture state]==NSOnState) {
				MLogString(2,@"%s removing aperture");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFNumber];
			}
			if ([mCopyFocal state]==NSOnState) {
				MLogString(2,@"removing focal length");
				[newExif removeObjectForKey:(NSString *)kCGImagePropertyExifFocalLength];
			}
			//[newExif  insertValue:[newExif valueForKey:@"ISOSpeedRating" ] inPropertyWithKey:@"ISOSpeedRating"];
		} /* kCGImagePropertyExifFocalLength kCGImagePropertyExifExposureTime kCGImagePropertyExifExposureTime */
		
		//add our modified EXIF data back into the image�s metadata
		[metadataAsMutable setObject:newExif forKey:(NSString *)kCGImagePropertyExifDictionary];
		
		//MLogString(1,@"the exif data will be : %@", [newExif description]);
		
		// create the destination
		CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)_outurl,
				CGImageSourceGetType(source),
				CGImageSourceGetCount(source),
				NULL);
	
		CGImageDestinationSetProperties(destination, (CFDictionaryRef)metadataAsMutable);	

		// copy data from temporary image ...
		int imageCount = CGImageSourceGetCount(source);
		int i;
		for (i = 0; i < imageCount; i++) {
				//NSLog(@"imgs  : %d",i);
				CGImageDestinationAddImageFromSource(destination,
						     source,
						     i,
						     (CFDictionaryRef)metadataAsMutable);
		}
    
		CGImageDestinationFinalize(destination);
    
		CFRelease(destination);
		CFRelease(source); 
	} else {
		NSRunInformationalAlertPanel(@"Copying Exif error!",
									 @"Unable to add Exif to Image.",
									 @"OK",
									 nil,
									 nil,
									 nil);
	}
	NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[self tempfile]]){
		[fm removeFileAtPath:[self tempfile] handler:self];
	}
#else
	NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:(tempfile)]){
              BOOL result = [fm movePath:tempfile toPath:outputfile handler:nil];
        } else {
              NSString *alert = [tempfile stringByAppendingString: @" do not exist!\nCan't rename"];
              NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""), alert, @"OK", NULL, NULL);
        }
#endif
		
		
		[mProgressIndicator stopAnimation:self];
		[mProgressIndicator setDoubleValue:0];
		[NSApp stopModal];
		MLogString(4,@"show preview of : %@",[self outputfile]);
		NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:[self outputfile]] autorelease];
		[mPreviewImage setImage:_image];			
		MLogString(6,@"out");
		[pool release];
}

// saving ?
- (NSData *) dataOfType: (NSString *) typeName
{

    NSMutableData *data = [[NSMutableData alloc] init];

    NSKeyedArchiver *archiver;
    archiver = [[NSKeyedArchiver alloc]
                   initForWritingWithMutableData: data];
    [archiver setOutputFormat: NSPropertyListXMLFormat_v1_0];

    [archiver encodeDouble: [mContrastSlider doubleValue]  forKey: @"contrast"];
    [archiver encodeDouble: [mExposureSlider doubleValue]  forKey: @"exposure"];
    [archiver encodeDouble: [mSaturationSlider doubleValue]  forKey: @"saturation"];

    [archiver encodeDouble: [mMuSlider doubleValue]  forKey: @"mu"];
    [archiver encodeDouble: [mSigmaSlider doubleValue]  forKey: @"sigma"];

    [archiver encodeDouble: [mContrastWindowSizeTextField doubleValue]  forKey: @"windowsize"];
    [archiver encodeDouble: [mMinCurvatureTextField doubleValue]  forKey: @"mincurvature"];

    [archiver finishEncoding];

    return ([data autorelease]);

} 

- (BOOL) readFromData: (NSData *) data
              ofType: (NSString *) typeName
{
    NSKeyedUnarchiver *archiver;
    archiver = [[NSKeyedUnarchiver alloc]
                   initForReadingWithData: data];

    //stitches = [archiver decodeObjectForKey: @"stitches"];

    return (YES);

} 

#pragma mark -
#pragma mark TaskWrapper

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
	MLogString(4 ,@"output is : [%@]", output);
    // add the string (a chunk of the results from locate) to the NSTextView's
    // backing store, in the form of an attributed string
    if ([output hasPrefix:@"Generating"] || [output hasPrefix:@"Collapsing"]  ||
		[output hasPrefix: @"Loading next image"] || [output hasPrefix: @"Using"] ) {
	    //MLogString(4 ,@"output is : [%@]", output);
#ifndef GNUSTEP
		//NSImage* progress = [myBadge badgeOverlayImageWithProgress:((value)/(2+4*[images count])) insetX:2 y:3];
#endif
    } /* else {
	MLogString(1 ,@"%d output is : [%@]",value, output);
    } */
	
    //[[resultsTextField textStorage] appendAttributedString: [[[NSAttributedString alloc]
    //                         initWithString: output] autorelease]];
    // setup a selector to be called the next time through the event loop to scroll
    // the view to the just pasted text.  We don't want to scroll right now,
    // because of a bug in Mac OS X version 10.1 that causes scrolling in the context
    // of a text storage update to starve the app of events
    //[self performSelector:@selector(scrollToVisible:) withObject:nil afterDelay:0.0];
}

// A callback that gets called when a TaskWrapper is launched, allowing us to do any setup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processStarted
{
    MLogString(6 ,@"");
	
    findRunningPreview=YES;
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished:(int)status
{
    MLogString(6 ,@"status %d",status);
	
    findRunningPreview=NO;
	NSImage* _image = [[[NSImage alloc] initWithContentsOfFile:[self previewfilename:@"enfuse.tif"]] autorelease];
	[mPreviewImage setImage:_image];
}


// return a somewhat globally unique filename ...
// 
-(NSString*)previewfilename:(NSString *)file
{
	NSString *tempFilename = [self temppath]; // NSTemporaryDirectory();
    
	return [[NSString stringWithFormat:@"%@/thumb_%@",tempFilename,file] retain];
}

-(void)buildPreview;
{
	MLogString(6 ,@"");
	
	if (findRunningPreview != NO) {
		MLogString(5 ,@"preview already running");
		return ;
	}	
	//MLogString(5 ,@"edit count : %d",[[_editManager selectedVersionIds] count]);
	if ([self countOfImages] == 0) {
		MLogString(5 ,@"preview : no images");
		return ;
	}
	
	NSMutableArray *args = [NSMutableArray array];
	
	NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
	NSString* enfuse_path = [NSString stringWithFormat:@"%@%@",[myBundle resourcePath],
		@"/enfuse"];
	
	MLogString(1 ,@"path %@",enfuse_path);
	
	[args addObject:enfuse_path];
	
	[args addObject:@"-o"];
	[args addObject:[self previewfilename:@"enfuse.tif"]];
	MLogString(4 ,@"preview file is %@",[self previewfilename:@"enfuse.tif"]);
	
	// gather thumbnail ...
	int i;
	int count = [self countOfImages];
	NSDictionary* obj=nil;
	
	for (i = 0; i < count; i++) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		obj = [self objectInImagesAtIndex:i];
		//MLogString(4 ,@"%@",obj);
		if (obj != nil) {
			NSString* path = [obj valueForKey:@"thumbfile"];
			if (path != nil) {
				//MLogString(4 ,@"add %@",path);
				[args addObject:path];
			}
		}
		[pool release];
	}

	
	// gather parameters ...
	[args addObject:[NSString stringWithFormat:@"--wExposure=%@",[mExposureSlider stringValue]]];
	[args addObject:[NSString stringWithFormat:@"--wSaturation=%@",[mSaturationSlider stringValue]]];
	[args addObject:[NSString stringWithFormat:@"--wContrast=%@",[mContrastSlider stringValue]]];
	
	[args addObject:[NSString stringWithFormat:@"--wMu=%@",[mMuSlider stringValue]]];
	[args addObject:[NSString stringWithFormat:@"--wSigma=%@",[mSigmaSlider stringValue]]];
	
	TaskWrapper* previewTask=[[TaskWrapper alloc] initWithController:self arguments:args];
	
	int status = [previewTask startProcess];
	if (status != 0) {
		NSRunAlertPanel (NSLocalizedString(@"Fatal Error",@""), @"running error", @"OK", NULL, NULL);
	} else  {
	       [previewTask waitUntilExit];
	}
}

@end
