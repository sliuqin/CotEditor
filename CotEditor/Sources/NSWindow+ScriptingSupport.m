/*
 =================================================
 NSWindow+ScriptingSupport
 (for CotEditor)
 
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
 =================================================
 
 encoding="UTF-8"
 Created:2014-03-12 by 1024jp
 
 -------------------------------------------------
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 
 =================================================
 */

#import "NSWindow+ScriptingSupport.h"
#import "CEWindowController.h"


@implementation NSWindow (ScriptingSupport)

#pragma mark AppleScript Accessores

//=======================================================
// AppleScript accessor
//
//=======================================================

// ------------------------------------------------------
/// テキストビューの不透明度を返す
- (NSNumber *)viewOpacity
// ------------------------------------------------------
{
    if ([self isDocumentWindow]) {
        return @([(CEWindowController *)[self windowController] alpha]);
        // AppleScript で値を得てみると、0.50000000113 とかになってしまう **** 2005.03.04
    }
    
    return nil;
}

// ------------------------------------------------------
/// テキストビューの不透明度をセット
- (void)setViewOpacity:(NSNumber *)viewOpacity
// ------------------------------------------------------
{
    if ([self isDocumentWindow]) {
        [(CEWindowController *)[self windowController] setAlpha:(CGFloat)[viewOpacity doubleValue]];
    }
}



#pragma mark Public Methods

//=======================================================
// Private Methods
//
//=======================================================

// ------------------------------------------------------
/// 自身が CEWindowController の支配下のウインドウかどうか
- (BOOL)isDocumentWindow
// ------------------------------------------------------
{
    return [[self windowController] isKindOfClass:[CEWindowController class]];
}

@end
