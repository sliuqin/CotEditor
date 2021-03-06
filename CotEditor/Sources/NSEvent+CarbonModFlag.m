/*
=================================================
NSEvent+CarbonModFlag
(for CotEditor)

 Copyright (C) 2004-2007 nakamuxu.
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
=================================================

encoding="UTF-8"
Created:2005.03.25

------------
This class was written and copyright by Hetima – http://hetima.com/
Description in http://hetima.com/pblog/article.php?id=48
included by nakamuxu, Mar 2005.
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

#import "NSEvent+CarbonModFlag.h"


@implementation NSEvent (CarbonModFlag)

+ (NSUInteger)currentCarbonModifierFlags
{
    NSUInteger cocoaModFlag = 0;
    UInt32 carbonModFlag = GetCurrentEventKeyModifiers();

    if (carbonModFlag & cmdKey)      cocoaModFlag |= NSCommandKeyMask;
    if (carbonModFlag & optionKey)   cocoaModFlag |= NSAlternateKeyMask;
    if (carbonModFlag & shiftKey)    cocoaModFlag |= NSShiftKeyMask;
    if (carbonModFlag & controlKey)  cocoaModFlag |= NSControlKeyMask;

    return cocoaModFlag;
}

@end
