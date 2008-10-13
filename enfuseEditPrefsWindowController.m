//
//  enfuseEditPrefsWindowController.m
//
//  Created by valery brasseur on 8/9/07.
//  Copyright 2007 Valery Brasseur. All rights reserved.
//

#import "enfuseEditPrefsWindowController.h"

@implementation enfuseEditPrefsWindowController

- (void)setupToolbar
{
  [self addView:generalPrefsView label:@"general" ];
  [self addView:updatePrefsView label:@"update"  ];
}

@end
