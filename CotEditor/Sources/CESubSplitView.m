/*
=================================================
CESubSplitView
(for CotEditor)

 Copyright (C) 2004-2007 nakamuxu.
 Copyright (C) 2014 CotEditor Project
 http://coteditor.github.io
=================================================

encoding="UTF-8"
Created:2006.03.18
 
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

#import "CESubSplitView.h"
#import "constants.h"


@interface CESubSplitView ()

@property (nonatomic) NSTimer *lineNumUpdateTimer;
@property (nonatomic) NSTimer *outlineMenuTimer;
@property (nonatomic) NSTimeInterval lineNumUpdateInterval;
@property (nonatomic) NSTimeInterval outlineMenuInterval;
@property (nonatomic) NSRange hilightedLineRange;
@property (nonatomic) NSRect hilightedLineRect;

@property (nonatomic) BOOL highlightCurrentLine;
@property (nonatomic) BOOL setsHiliteLineColorToIMChars;
@property (nonatomic) BOOL hadMarkedText;
@property (nonatomic) NSInteger lastCursorLocation;


// readonly
@property (nonatomic, readwrite) NSScrollView *scrollView;
@property (nonatomic, readwrite) CETextViewCore *textView;
@property (nonatomic, readwrite) CELineNumView *lineNumView;
@property (nonatomic, readwrite) CENavigationBarView *navigationBar;
@property (nonatomic, readwrite) CESyntax *syntax;
@property (nonatomic, readwrite) NSDictionary *highlightBracesColorDict;
@property (nonatomic, readwrite) NSTextStorage *textStorage;

@end





#pragma mark -

@implementation CESubSplitView

#pragma mark NSView Methods

//=======================================================
// NSView method
//
//=======================================================

// ------------------------------------------------------
/// 初期化
- (instancetype)initWithFrame:(NSRect)frameRect
// ------------------------------------------------------
{
    self = [super initWithFrame:frameRect];

    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

        [self setLastCursorLocation:0];

        // LineNumView 生成
        NSRect lineMumFrame = frameRect;
        lineMumFrame.size.width = 0.0; // default width (about invisible).
        [self setLineNumView:[[CELineNumView alloc] initWithFrame:lineMumFrame]];
        [[self lineNumView] setMasterView:self];
        [self addSubview:[self lineNumView]];

        // navigationBar 生成
        NSRect navigationFrame = frameRect;
        navigationFrame.origin.y = NSHeight(navigationFrame);
        navigationFrame.size.height = 0.0;
        [self setNavigationBar:[[CENavigationBarView alloc] initWithFrame:navigationFrame]];
        [[self navigationBar] setMasterView:self];
        [self addSubview:[self navigationBar]];

        [self setScrollView:[[NSScrollView alloc] initWithFrame:frameRect]];
        [[self scrollView] setBorderType:NSNoBorder];
        [[self scrollView] setHasVerticalScroller:YES];
        [[self scrollView] setHasHorizontalScroller:YES];
        [[self scrollView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [[self scrollView] setAutohidesScrollers:NO];
        [[self scrollView] setDrawsBackground:NO];
        [[[self scrollView] contentView] setAutoresizesSubviews:YES];
        // （splitViewをリサイズした時に最後までナビバーを表示させるため、その下に配置する）
        [self addSubview:[self scrollView] positioned:NSWindowBelow relativeTo:[self navigationBar]];

        // TextStorage と LayoutManager を生成
        [self setTextStorage:[[NSTextStorage alloc] init]];
        CELayoutManager *layoutManager = [[CELayoutManager alloc] init];
        [[self textStorage] addLayoutManager:layoutManager];
        [layoutManager setBackgroundLayoutEnabled:YES];
        [layoutManager setUseAntialias:[defaults boolForKey:k_key_shouldAntialias]];
        [layoutManager setFixLineHeight:[defaults boolForKey:k_key_fixLineHeight]];

        // NSTextContainer と CESyntax を生成
        NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
        [layoutManager addTextContainer:container];

        [self setSyntax:[[CESyntax alloc] init]];
        [[self syntax] setSyntaxStyleName:NSLocalizedString(@"None",@"")];
        [[self syntax] setLayoutManager:layoutManager];
        [[self syntax] setIsPrinting:NO];

        // TextView 生成
        NSRect textFrame;
        textFrame.origin = NSZeroPoint;
        textFrame.size = [[self scrollView] contentSize]; // (frame will start at upper left.)
        [self setTextView:[[CETextViewCore alloc] initWithFrame:textFrame textContainer:container]];
        [[self textView] setDelegate:self];
        
        // OgreKit 改造でポストするようにしたノーティフィケーションをキャッチ
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidReplaceAll:)
                                                     name:@"textDidReplaceAllNotification"
                                                   object:nil];
        [[self scrollView] setDocumentView:[self textView]];

        // slave view をセット
        [[self textView] setSlaveView:[self lineNumView]]; // (the textview will also update slaveView.)
        [[self textView] setPostsBoundsChangedNotifications:YES]; // observer = lineNumView
        [[NSNotificationCenter defaultCenter] addObserver:[self lineNumView]
                                                 selector:@selector(updateLineNumber:)
                                                     name:NSViewBoundsDidChangeNotification
                                                   object:[[self scrollView] contentView]];

        // ビューのパラメータをセット
        [[self textView] setTextContainerInset:
                NSMakeSize((CGFloat)[defaults doubleForKey:k_key_textContainerInsetWidth],
                           ((CGFloat)[defaults doubleForKey:k_key_textContainerInsetHeightTop] +
                            (CGFloat)[defaults doubleForKey:k_key_textContainerInsetHeightBottom]) / 2
                           )];
        [self setLineNumUpdateTimer:nil];
        [self setOutlineMenuTimer:nil];
        [self setLineNumUpdateInterval:[defaults doubleForKey:k_key_lineNumUpdateInterval]];
        [self setOutlineMenuInterval:[defaults doubleForKey:k_key_outlineMenuInterval]];
        [self setHighlightBracesColorDict:[[NSDictionary alloc] initWithObjectsAndKeys:
                    [NSUnarchiver unarchiveObjectWithData:[defaults valueForKey:k_key_selectionColor]],
                    NSBackgroundColorAttributeName, nil]];
        [self setHighlightCurrentLine:[defaults boolForKey:k_key_highlightCurrentLine]];
        [self setSetsHiliteLineColorToIMChars:[defaults boolForKey:k_key_setHiliteLineColorToIMChars]];
        [self setHadMarkedText:NO];

    }
    return self;
}


// ------------------------------------------------------
/// 後片づけ
- (void)dealloc
// ------------------------------------------------------
{
    [self stopUpdateLineNumberTimer];
    [self stopUpdateOutlineMenuTimer];
    [self setEditorView:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:[self lineNumView]];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [[self textView] setDelegate:nil];
}



#pragma mark Public Methods

//=======================================================
// Public method
//
//=======================================================

// ------------------------------------------------------
/// editorView 開放
- (void)releaseEditorView
// ------------------------------------------------------
{
    // （dealloc は親階層から行われるため、あらかじめ「子」が持っている「親」を開放しておく）
    [self setEditorView:nil];
}


// ------------------------------------------------------
/// テキストビューの文字列を返す
- (NSString *)string
// ------------------------------------------------------
{
    return ([[self textView] string]);
}


// ------------------------------------------------------
/// ライブリサイズが終了した
- (void)viewDidEndLiveResize
// ------------------------------------------------------
{
    // ナビゲーションバーを表示させているときにスプリットビューを最小までリサイズしてから広げると、テキストが
    // ナビバーを上書きしてしまうことへの対応措置。
    if ([[self editorView] showNavigationBar]) {
        [[self scrollView] setFrameSize:NSMakeSize([[self scrollView] frame].size.width,
                                                   [self frame].size.height - k_navigationBarHeight)];
    }
}


// ------------------------------------------------------
/// TextStorage を置換
- (void)replaceTextStorage:(NSTextStorage *)textStorage
// ------------------------------------------------------
{
    _textStorage = textStorage;
    [[[self textView] layoutManager] replaceTextStorage:textStorage];
}


// ------------------------------------------------------
/// ドキュメントが書き込みできるかどうかを返す
- (BOOL)isWritable
// ------------------------------------------------------
{
    return [[self editorView] isWritable];
}


// ------------------------------------------------------
/// 「書き込み禁止」アラートを表示したかどうかを返す
- (BOOL)isAlertedNotWritable
// ------------------------------------------------------
{
    return [[self editorView] isAlertedNotWritable];
}


// ------------------------------------------------------
/// テキストビューをエディタビューにセット
- (void)setTextViewToEditorView:(CETextViewCore *)textView
// ------------------------------------------------------
{
    [[self editorView] setTextView:textView];
}


// ------------------------------------------------------
/// 行番号表示設定をセット
- (void)setShowLineNumWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    [[self lineNumView] setShowLineNum:[number boolValue]];
}


// ------------------------------------------------------
/// ナビゲーションバーを表示／非表示
- (void)setShowNavigationBarWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    [[self navigationBar] setShowNavigationBar:[number boolValue]];
    if (![self outlineMenuTimer]) {
        [self updateOutlineMenu];
    }
}


// ------------------------------------------------------
/// ラップする／しないを切り替える
- (void)setWrapLinesWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    if ([number boolValue]) {
        [[[self textView] enclosingScrollView] setHasHorizontalScroller:NO];
        [[self textView] setAutoresizingMask:NSViewWidthSizable];
        [self adjustTextFrameSize];
        [[[self textView] textContainer] setWidthTracksTextView:YES]; // (will follow the width of the textview.)
        [[self textView] sizeToFit];
        [[self textView] setHorizontallyResizable:NO];
    } else {
        [[[self textView] enclosingScrollView] setHasHorizontalScroller:YES];
        [[[self textView] textContainer] setWidthTracksTextView:NO];
        [[[self textView] textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)]; // set the frame size
        [[self textView] setAutoresizingMask:NSViewNotSizable]; // (don't let it autosize, though.)
        [[self textView] setHorizontallyResizable:YES];
    }

}


// ------------------------------------------------------
/// 不可視文字の表示／非表示を切り替える
- (void)setShowInvisiblesWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    NSRange selectedRange;
    BOOL shouldReselect = NO;

    if ([number boolValue]) {
        shouldReselect = YES;
        selectedRange = [[self textView] selectedRange];
        [[self textView] setSelectedRange:NSMakeRange(0, 0)]; // （選択範囲をリセットしておき、あとで再選択）
    }
    [(CELayoutManager *)[[self textView] layoutManager] setShowInvisibles:[number boolValue]];
    [[self textView] setNeedsDisplay:YES];
    if (shouldReselect) {
        // （不可視文字が選択状態で表示／非表示を切り替えられた時、不可視文字の背景選択色を描画するための時間差での選択処理）
        // （もっとスマートな解決方法はないものか...？ 2006.09.25）
        [[self textView] performSelector:@selector(selectTextRangeValue:)
                              withObject:[NSValue valueWithRange:selectedRange]
                              afterDelay:0];
    }
}


// ------------------------------------------------------
/// アンチエイリアス適用を切り替える
- (void)setUseAntialiasWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    CELayoutManager *manager = (CELayoutManager *)[[self textView] layoutManager];

    [manager setUseAntialias:[number boolValue]];
    [[self textView] setNeedsDisplay:YES];
}


// ------------------------------------------------------
/// ページガイドの表示／非表示を返す
- (BOOL)showPageGuide
// ------------------------------------------------------
{
    return [[self editorView] showPageGuide];
}


// ------------------------------------------------------
/// キャレットを先頭に移動
- (void)setCaretToBeginning
// ------------------------------------------------------
{
    [[self textView] setSelectedRange:NSMakeRange(0, 0)];
}


// ------------------------------------------------------
/// シンタックススタイルを設定
- (void)setSyntaxStyleNameToSyntax:(NSString *)styleName
// ------------------------------------------------------
{
    [[self syntax] setSyntaxStyleName:styleName];
}


// ------------------------------------------------------
/// 全てを再カラーリング
- (void)recoloringAllTextViewString
// ------------------------------------------------------
{
    [[self syntax] colorAllString:[[self textView] string]];
}


// ------------------------------------------------------
/// アウトラインメニューを更新
- (void)updateOutlineMenu
// ------------------------------------------------------
{
    [self stopUpdateOutlineMenuTimer];
    [[self navigationBar] setOutlineMenuArray:[[[self editorView] syntax] outlineMenuArrayWithWholeString:[self string]]];
    // （選択項目の更新も上記メソッド内で行われるので、updateOutlineMenuSelection は呼ぶ必要なし。 2008.05.16.）
}


// ------------------------------------------------------
/// アウトラインメニューの選択項目を更新
- (void)updateOutlineMenuSelection
// ------------------------------------------------------
{
    if (![self outlineMenuTimer]) {
        if ([[self textView] updateOutlineMenuItemSelection]) {
            [[self navigationBar] performSelector:@selector(selectOutlineMenuItemWithRangeValue:)
                                       withObject:[NSValue valueWithRange:[[self textView] selectedRange]]
                                       afterDelay:0.01];
        } else {
            [[self textView] setUpdateOutlineMenuItemSelection:YES];
            [[self navigationBar] performSelector:@selector(updatePrevNextButtonEnabled)
                                       withObject:nil
                                       afterDelay:0.01];
        }
    }
}


// ------------------------------------------------------
/// テキストビュー分割削除ボタンの有効化／無効化を制御
- (void)updateCloseSubSplitViewButtonWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    [[self navigationBar] setCloseSplitButtonEnabled:[number boolValue]];
}


// ------------------------------------------------------
/// 行番号更新タイマーを停止
- (void)stopUpdateLineNumberTimer
// ------------------------------------------------------
{
    if ([self lineNumUpdateTimer]) {
        [[self lineNumUpdateTimer] invalidate];
        [self setLineNumUpdateTimer:nil];
    }
}


// ------------------------------------------------------
/// アウトラインメニュー更新タイマーを停止
- (void)stopUpdateOutlineMenuTimer
// ------------------------------------------------------
{
    if ([self outlineMenuTimer]) {
        [[self outlineMenuTimer] invalidate];
        [self setOutlineMenuTimer:nil];
    }
}


// ------------------------------------------------------
/// 入力補完文字列に設定された最初の1文字のセットを返す
- (NSCharacterSet *)completionsFirstLetterSet
// ------------------------------------------------------
{
    return [[self syntax] completeFirstLetterSet];
}


// ------------------------------------------------------
/// テキストビューに背景色をセット
- (void)setBackgroundColorAlphaWithNumber:(NSNumber *)number
// ------------------------------------------------------
{
    CGFloat alpha = (CGFloat)[number doubleValue];
    
    [[self textView] setBackgroundColorWithAlpha:alpha];
    [[self lineNumView] setBackgroundAlpha:alpha];
    [[self lineNumView] setNeedsDisplay:YES];
}



#pragma mark Delegate and Notification

//=======================================================
// Delegate method (CETextViewCore)
//  <== textView
//=======================================================

// ------------------------------------------------------
///  テキストが編集される
- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange 
        replacementString:(NSString *)replacementString
// ------------------------------------------------------
{
    // キー入力、スクリプトによる編集で行末コードをLFに統一する
    // （その他の編集は、下記の通りの別の場所で置換している）
    // # テキスト編集時の行末コードの置換場所
    //  * ファイルオープン = CEEditorView > setString:
    //  * キー入力 = CESubSplitView > textView:shouldChangeTextInRange:replacementString:
    //  * ペースト = CETextViewCore > readSelectionFromPasteboard:type:
    //  * ドロップ（同一書類内） = CETextViewCore > performDragOperation:
    //  * ドロップ（別書類または別アプリから） = CETextViewCore > readSelectionFromPasteboard:type:
    //  * スクリプト = CESubSplitView > textView:shouldChangeTextInRange:replacementString:
    //  * 検索パネルでの置換 = (OgreKit) OgreTextViewPlainAdapter > replaceCharactersInRange:withOGString:

    if ((replacementString == nil) || // = attributesのみの変更
            ([replacementString length] == 0) || // = 文章の削除
            ([(CETextViewCore *)aTextView isSelfDrop]) || // = 自己内ドラッグ&ドロップ
            ([(CETextViewCore *)aTextView isReadingFromPboard]) || // = ペーストまたはドロップ
            ([[aTextView undoManager] isUndoing])) { return YES; } // = アンドゥ中

    NSString *newStr = nil;

    if (![replacementString isEqualToString:@"\n"]) {
        OgreNewlineCharacter replacementLineEndingChar = [OGRegularExpression newlineCharacterInString:replacementString];
        // 挿入／置換する文字列に行末コードが含まれていたら、LF に置換する
        if ((replacementLineEndingChar != OgreNonbreakingNewlineCharacter) &&
            (replacementLineEndingChar != OgreLfNewlineCharacter)) {
            // （theNewStrが使用されるのはスクリプトからの入力時。キー入力は条件式を通過しない）
            newStr = [OGRegularExpression replaceNewlineCharactersInString:replacementString
                                                             withCharacter:OgreLfNewlineCharacter];
        }
    }
    if (newStr != nil) {
        // （Action名は自動で付けられる？ので、指定しない）
        [(CETextViewCore *)aTextView doReplaceString:newStr
                                           withRange:affectedCharRange
                                        withSelected:NSMakeRange(affectedCharRange.location + [newStr length], 0)
                                      withActionName:@""];

        return NO;
    }
    return YES;
}


// ------------------------------------------------------
/// 補完候補リストをセット
- (NSArray *)textView:(NSTextView *)aTextView completions:(NSArray *)words 
        forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
// ------------------------------------------------------
{
    // This method is based on Smultron(SMLSyntaxColouring.m)
    //  written by Peter Borg. Copyright (C) 2004 Peter Borg.
    // http://smultron.sourceforge.net

    NSUInteger addingStandard = [[NSUserDefaults standardUserDefaults] integerForKey:k_key_completeAddStandardWords];
    NSMutableArray *outArray = [NSMutableArray arrayWithCapacity:[words count]];
    NSEnumerator *enumerator;
    NSString *curStr = [[aTextView string] substringWithRange:charRange];
    NSString *arrayStr;

    //"ファイル中の語彙" を検索して outArray に入れる
    {
        OGRegularExpression *regex = [OGRegularExpression regularExpressionWithString: 
            [NSString stringWithFormat:@"(?:^|\\b|(?<=\\W))%@\\w+?(?:$|\\b)",
                [OGRegularExpression regularizeString:curStr]]];
        enumerator = [regex matchEnumeratorInString:[aTextView string]];
        OGRegularExpressionMatch *match;
        while (match = [enumerator nextObject]) {
            if (![outArray containsObject:[match matchedString]]) {
                [outArray addObject:[match matchedString]];
            }
        }
    }
    
    //"カラーシンタックス辞書の語彙" をコピーする
    if (addingStandard >= 1) {
        NSArray *syntaxWordsArray = [[self syntax] completeWordsArray];
        for (arrayStr in syntaxWordsArray) {
            if ([arrayStr rangeOfString:curStr options:NSCaseInsensitiveSearch
                                  range:NSMakeRange(0, [arrayStr length])].location == 0 && ![outArray containsObject:arrayStr]) {
                [outArray addObject:arrayStr];
            }
        }
    }
    
    //デフォルトの候補から "一般英単語" をコピーする
    if (addingStandard >= 2) {
        for (arrayStr in words) {
            //デフォルトの候補は "ファイル中の語彙" "一般英単語" の順に並んでいる
            //そのうち "ファイル中の語彙" 部分をスキップする
            if (![outArray containsObject:arrayStr]) {
                [outArray addObject:arrayStr];
                [outArray addObjectsFromArray:[enumerator allObjects]];
                break;
            }
        }
    }

    return outArray;
}



//=======================================================
// Notification method (NSTextView)
//  <== CETextViewCore
//=======================================================

// ------------------------------------------------------
/// text did edit.
- (void)textDidChange:(NSNotification *)aNotification
// ------------------------------------------------------
{
    // カラーリング実行
    [[self editorView] setupColoringTimer];

    // 行番号、アウトラインメニュー項目、非互換文字リスト更新
    [self updateInfo];

    // フラグが立っていたら、入力補完を再度実行する
    // （フラグは CETextViewCore > insertCompletion:forPartialWordRange:movement:isFinal: で立てている）
    if ([[self textView] isReCompletion]) {
        [[self textView] setIsReCompletion:NO];
        [[self textView] performSelector:@selector(complete:) withObject:nil afterDelay:0.05];
    }
}


// ------------------------------------------------------
/// the selection of main textView was changed.
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
// ------------------------------------------------------
{
    // カレント行をハイライト
    [self showHighlightCurrentLine];

    // 文書情報更新
    [[self editorView] setupInfoUpdateTimer];

    // アウトラインメニュー選択項目更新
    [self updateOutlineMenuSelection];

    // 対応するカッコをハイライト表示
// 以下の部分は、Smultron を参考にさせていただきました。(2006.09.09)
// This method is based on Smultron.(written by Peter Borg – http://smultron.sourceforge.net)
// Smultron  Copyright (c) 2004-2005 Peter Borg, All rights reserved.
// Smultron is released under GNU General Public License, http://www.gnu.org/copyleft/gpl.html

    if (![[NSUserDefaults standardUserDefaults] boolForKey:k_key_highlightBraces]) { return; }
    
    NSString *string = [self string];
    NSInteger stringLength = [string length];
    if (stringLength == 0) { return; }
    NSRange selectedRange = [[self textView] selectedRange];
    NSInteger location = selectedRange.location;
    NSInteger difference = location - [self lastCursorLocation];
    [self setLastCursorLocation:location];

    // Smultron では「if (difference != 1 && difference != -1)」の条件を使ってキャレットを前方に動かした時も強調表示させているが、CotEditor では Xcode 同様、入力時またはキャレットを後方に動かした時だけに限定した（2006.09.10）
    if (difference != 1) {
        return; // If the difference is more than one, they've moved the cursor with the mouse or it has been moved by resetSelectedRange below and we shouldn't check for matching braces then
    }
    
    if (difference == 1) { // Check if the cursor has moved forward
        location--;
    }

    if (location == stringLength) {
        return;
    }
    
    unichar theUnichar = [string characterAtIndex:location];
    unichar curChar, braceChar;
    if (theUnichar == ')') {
        braceChar = k_braceCharList[0];
    } else if (theUnichar == ']') {
        braceChar = k_braceCharList[1];
    } else if (theUnichar == '}') {
        braceChar = k_braceCharList[2];
    } else if ((theUnichar == '>') && [[NSUserDefaults standardUserDefaults] boolForKey:k_key_highlightLtGt]) {
        braceChar = k_braceCharList[3];
    } else {
        return;
    }
    NSUInteger skipMatchingBrace = 0;
    curChar = theUnichar;

    while (location--) {
        theUnichar = [string characterAtIndex:location];
        if (theUnichar == braceChar) {
            if (!skipMatchingBrace) {
                [[[self textView] layoutManager] addTemporaryAttributes:[self highlightBracesColorDict]
                                                      forCharacterRange:NSMakeRange(location, 1)];
                [self performSelector:@selector(resetBackgroundColor:)
                           withObject:NSStringFromRange(NSMakeRange(location, 1))
                           afterDelay:0.12];
                return;
            } else {
                skipMatchingBrace--;
            }
        } else if (theUnichar == curChar) {
            skipMatchingBrace++;
        }
    }
    NSBeep();
}


//=======================================================
// Notification method (OgreKit 改)
//  <== OgreReplaceAllThread
//=======================================================

// ------------------------------------------------------
/// did Replace All
- (void)textDidReplaceAll:(NSNotification *)aNotification
// ------------------------------------------------------
{
    // 文書情報更新（選択範囲・キャレット位置が変更されないまま全置換が実行された場合への対応）
    [[self editorView] setupInfoUpdateTimer];
    // 全テキストを再カラーリング
    [self performSelector:@selector(recoloringAllTextViewString) withObject:nil afterDelay:0];
    // 行番号、アウトラインメニュー項目、非互換文字リスト更新
    [self updateInfo];
}



#pragma mark Private Mthods

//=======================================================
// Private method
//
//=======================================================

// ------------------------------------------------------
/// ラップする時にサイズを適正化する
- (void)adjustTextFrameSize
// ------------------------------------------------------
{
    NSInteger newWidth = [[self scrollView] contentSize].width;

    newWidth -= (NSWidth([[self lineNumView] frame]) + k_lineNumPadding * 2 );
    [[[self textView] textContainer] setContainerSize:NSMakeSize(newWidth, FLT_MAX)];
}


// ------------------------------------------------------
/// 行番号更新
- (void)doUpdateLineNumberWithTimer:(NSTimer *)timer
// ------------------------------------------------------
{
    [self stopUpdateLineNumberTimer];
    [[self lineNumView] updateLineNumber:self];
}


// ------------------------------------------------------
/// アウトラインメニュー更新
- (void)doUpdateOutlineMenuWithTimer:(NSTimer *)timer
// ------------------------------------------------------
{
    [self updateOutlineMenu]; // （updateOutlineMenu 内で stopUpdateOutlineMenuTimer を実行している）
}


// ------------------------------------------------------
/// 対応カッコハイライト表示をリセット
- (void)resetBackgroundColor:(id)sender
// ------------------------------------------------------
{
    [[[self textView] layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName
                                            forCharacterRange:NSRangeFromString(sender)];
}


// ------------------------------------------------------
/// 行番号表示、アウトラインメニューなどを更新
- (void)updateInfo
// ------------------------------------------------------
{
    // 行番号更新
    if ([self lineNumUpdateTimer]) {
        [[self lineNumUpdateTimer] setFireDate:[NSDate dateWithTimeIntervalSinceNow:[self lineNumUpdateInterval]]];
    } else {
        [self setLineNumUpdateTimer:[NSTimer scheduledTimerWithTimeInterval:[self lineNumUpdateInterval]
                                                                     target:self
                                                                   selector:@selector(doUpdateLineNumberWithTimer:)
                                                                   userInfo:nil
                                                                    repeats:NO]];
    }

    // アウトラインメニュー項目更新
    if ([self outlineMenuTimer]) {
        [[self outlineMenuTimer] setFireDate:[NSDate dateWithTimeIntervalSinceNow:[self outlineMenuInterval]]];
    } else {
        [self setOutlineMenuTimer:[NSTimer scheduledTimerWithTimeInterval:[self outlineMenuInterval]
                                                                   target:self
                                                                 selector:@selector(doUpdateOutlineMenuWithTimer:)
                                                                 userInfo:nil
                                                                  repeats:NO]];
    }

    // 非互換文字リスト更新
    [[self editorView] setupIncompatibleCharTimer];
}


// ------------------------------------------------------
/// カレント行をハイライト表示
- (void)showHighlightCurrentLine
// ------------------------------------------------------
{
    if (![self highlightCurrentLine]) { return; }

// IMでの仮名漢字変換中に背景色がカレント行ハイライト色でなくテキスト背景色になることがあるため、行の文字数の変化や追加描画矩形の
// 比較では、描画をパスできない。
// hasMarkedText を使っても、変換確定の直前直後の区別がつかないことがあるので、愚直に全工程を実行している。 2008.05.31.

    CELayoutManager *layoutManager = (CELayoutManager *)[[self textView] layoutManager];

// グリフがないときはそのまま戻ると、全くハイライトされないことと、アンドゥで描画が乱れるため、実行する。2008.06.21.
//    NSUInteger numOfGlyphs = [layoutManager numberOfGlyphs];
//    if (numOfGlyphs == 0) { return; }
    NSRange selectedRange = [[self textView] selectedRange];
    NSRange lineRange = [[self string] lineRangeForRange:selectedRange];

    // 文字背景色でハイライトされる矩形を取得
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:lineRange actualCharacterRange:NULL];
    NSRect attrsRect = [layoutManager boundingRectForGlyphRange:glyphRange
                                                inTextContainer:[[self textView] textContainer]];
    // 10.5.5でdeleteキーで最終行の文字をすべて削除すると、ハイライトが文頭に移動してしまう。これはboundingRectForGlyphRange:inTextContainer:でZeroRectが返ってきてしまうために起こる。extraLineFragmentRectも試したが、やはりZeroRectしか返ってこなかった。この不具合を迂回するための条件式を設定したが、最後に削除した文字列の背景部分のみハイライトしないままになる問題が残ってる。2008.11.15
    if (([[self string] length] == 0) ||
        ((!NSEqualRects(attrsRect, NSZeroRect)) && ([[self string] length] > 0))) {
        // 文字背景色を塗っても右側に生じる「空白」の矩形を得る
        CGFloat additionalWidth = [[[self textView] textContainer] containerSize].width
                        - attrsRect.size.width - attrsRect.origin.x
                        - [[self textView] textContainerInset].width
                        - [[[self textView] textContainer] lineFragmentPadding];
        NSRect additionalRect = NSMakeRect(NSMaxX(attrsRect),
                    NSMinY(attrsRect) + [[self textView] textContainerOrigin].y, additionalWidth, 
                    [layoutManager lineHeight]);
    //NSLog(NSStringFromRange(glyphRange));
    //NSLog(NSStringFromRect(attrsRect));
    //NSLog(NSStringFromRange(lineRange));

        // 追加描画矩形を描画する
        if (!NSEqualRects([[self textView] highlightLineAdditionalRect], additionalRect)) {
            [[self textView] setNeedsDisplayInRect:[[self textView] highlightLineAdditionalRect]];
            [[self textView] setHighlightLineAdditionalRect:additionalRect];
            [[self textView] setNeedsDisplayInRect:additionalRect];
        }
    }

    // 古い範囲の文字背景色を削除し、新しい範囲にセット
    BOOL shouldSetBackgroundColor = [self setsHiliteLineColorToIMChars] ? YES :
                    (([self hadMarkedText] == [[self textView] hasMarkedText]) &&
                                    (!NSEqualRanges([self hilightedLineRange], lineRange)));
    if (shouldSetBackgroundColor) {

        NSColor *highlightColor = [[[self textView] highlightLineColor] colorWithAlphaComponent:
                    [[[self textView] backgroundColor] alphaComponent]];
        NSDictionary *dict = @{NSBackgroundColorAttributeName: highlightColor};
        // （文字列が削除されたときも実行されるので、範囲を検証しておかないと例外が発生する）
        NSRange removeAttrsRange = NSMakeRange(0, [[self textStorage] length]);

        // 検索パネルのハイライトや非互換文字表示で使っているlayoutManのaddTemporaryAttributesと衝突しないように、
        // NSTextStorageの背景色を使っている。addTemporaryAttributesよりも後ろに描画されるので、
        // これら検索パネルのハイライト／非互換文字表示／カレント行のハイライトが全て表示できる。
        // ただし、テキストビュー分割時にアクティブでないものも含めて全てのテキストビューがハイライトされてしまう。
        // これは、全テキストビューのtextStorageが共通であることに起因するので、構造を変更しない限り解決できない。2008.06.07.
        [[self textStorage] beginEditing];
        if (removeAttrsRange.length > 0) {
            [[self textStorage] removeAttribute:NSBackgroundColorAttributeName range:removeAttrsRange];
        }
        [[self textStorage] addAttributes:dict range:lineRange];
        [[self textStorage] endEditing];
        [self setHilightedLineRange:lineRange];
        [self setHadMarkedText:[[self textView] hasMarkedText]];
    }
}

@end
