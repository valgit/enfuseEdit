#import "ExportOptionsController.h"

@implementation ExportOptionsController

- (NSString *)windowNibName { return @"ExportOptions"; }

- (id)init
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	if (![super initWithWindowNibName:[self windowNibName]])
		return nil;
	// [NSBundle loadNibNamed:@"ExportOptions" owner:self];
	[self window];
	return self;
}

- (void)dealloc;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	[super dealloc];
}


- (void)runSheet:(NSWindow*)parentWindow selector:(SEL)sel target:(id)target;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
    _selector = sel;
    _target = target; // don't retain
	
    // init outlet here ...
    //[widthTextField setFloatValue:_initialSize.width];
	
    [NSApp beginSheet: [self window]
       modalForWindow: parentWindow
        modalDelegate: self
       didEndSelector: @selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
		  
	//[NSApp runModalForWindow: [self window]];
	//NSLog(@"%s out",__PRETTY_FUNCTION__);
}


- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
    [sheet close];
}

#pragma mark -

- (IBAction)cancelAction:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
    [NSApp endSheet: [self window] returnCode:NSCancelButton];
}

- (IBAction)okAction:(id)sender
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
    [NSApp endSheet: [self window] returnCode:NSOKButton];
	
    // call the sheet is done action
    if (_selector && _target)
		[_target performSelector:_selector withObject:self];
}

- (IBAction)chooseDirectory:(id)sender;
{
	NSLog(@"%s",__PRETTY_FUNCTION__);
	   NSOpenPanel* oPanel = [NSOpenPanel openPanel];

        [oPanel setCanChooseDirectories:YES];
        [oPanel setCanChooseFiles:NO];
        [oPanel setCanCreateDirectories:YES];
        [oPanel setAllowsMultipleSelection:NO];
        [oPanel setAlphaValue:0.95];
        [oPanel setTitle:@"Select a directory for output"];

	if ( [oPanel runModalForDirectory:[mExportDirectory stringValue] file:nil types:nil]
                 == NSOKButton ) {
                // Get an array containing the full filenames of all
                // files and directories selected.
                NSArray* files = [oPanel filenames];

                NSString* fileName = [files objectAtIndex:0];
                NSLog(fileName);
		[mExportDirectory setStringValue:fileName];
        }

}

#pragma mark -

- (NSString*)keyword;
{
    return [mKeywordField stringValue];
}

- (void)setKeyword:(NSString*)newkey;
{
    [mKeywordField setStringValue:newkey];
}

-(BOOL)ImportInAperture;
{
	return [mImportInAperture state] == NSOnState;
}

-(void)setImportInAperture:(BOOL)state;
{
	if (state == YES)
		[mImportInAperture setState:NSOnState];
	else
		[mImportInAperture setState:NSOffState];
}

-(BOOL)stackWithOriginal;
{
	return [mstackWithOriginal state] == NSOnState;
}

-(void)stackWithOriginal:(BOOL)state;
{
	if (state == YES)
		[mstackWithOriginal setState:NSOnState];
	else
		[mstackWithOriginal setState:NSOffState];
}

-(BOOL)AddKeyword;
{
	return [mAddKeyword state] == NSOnState;
}

-(void)setAddKeyword:(BOOL)state;
{
	if (state == YES)
		[mAddKeyword setState:NSOnState];
	else
		[mAddKeyword setState:NSOffState];
}

-(NSString*)exportDirectory;
{
	return [mExportDirectory stringValue];
}

-(void)setExportDirectory:(NSString*)directory;
{
	[mExportDirectory setStringValue:directory];
}

@end

