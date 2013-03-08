//
//  NLMenulet.m
//  NumLock
//
//  Created by Christian A. Strømmen on 07.03.13.
//  Copyright (c) 2013 Object Factory. All rights reserved.
//

#import "NLMenulet.h"
#import "DDHotKeyCenter.h"
#import <ServiceManagement/ServiceManagement.h>

@interface NLMenulet ()

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic) BOOL enabled;
@property (nonatomic) CFMachPortRef eventTap;
@property (nonatomic) CFRunLoopSourceRef runLoopSource;
@property (nonatomic, strong) NSWindow *alertWindow;
@property (nonatomic, strong) NSWindowController *alertController;
@property (nonatomic, strong) NSTimer *alertTimer;
@property (nonatomic, strong) NSMenuItem *toggleItem, *launchItem;

@end

@implementation NLMenulet

- (id)init
{
    self = [super init];
    
    if(self) {
        [self createStatusItem];
        
        [self buildMenu];
        
        _enabled = NO;
        
        DDHotKeyCenter * c = [[DDHotKeyCenter alloc] init];
        if(![c registerHotKeyWithKeyCode:45
                           modifierFlags:NSControlKeyMask | NSShiftKeyMask
                                  target:self
                                  action:@selector(hotkeyWithEvent:)
                                  object:nil]) {
            NSLog(@"Unable to register hotkey");
        }
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [self init];
    
    if(self) {
        if([aDecoder decodeBoolForKey:@"enabled"]) {
            [self toggleNumLock];
        }
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_enabled
                forKey:@"enabled"];
}

#pragma mark - Hotkeys

- (void)hotkeyWithEvent:(NSEvent *)hkEvent
{
    [self toggleNumLock];
}

- (void)hotkeyWithEvent:(NSEvent *)hkEvent object:(id)anObject
{
}

#pragma mark - UI

- (void)createStatusItem
{
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem setHighlightMode:YES];
    [_statusItem setEnabled:YES];
    [_statusItem setImage:[NSImage imageNamed:@"disabled"]];
}

- (void)buildMenu
{
    NSMenu *popupMenu = [[NSMenu alloc] initWithTitle:@"NumLock"];
    [popupMenu setDelegate:self];
    [_statusItem setMenu:popupMenu];
    
    _toggleItem = [[NSMenuItem alloc] initWithTitle:@"Toggle NumLock"
                                             action:@selector(toggleNumLock)
                                      keyEquivalent:@"n"];
    [_toggleItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    [_toggleItem setTarget:self];
    [_toggleItem setEnabled:YES];
    [popupMenu addItem:_toggleItem];
    
    [popupMenu addItem:[NSMenuItem separatorItem]];

    _launchItem = [[NSMenuItem alloc] initWithTitle:@"Launch on login"
                                             action:@selector(toggleLaunchOnLogin)
                                      keyEquivalent:@""];
    [_launchItem setTarget:self];
    [_launchItem setEnabled:YES];
    if([self launchOnLogin]) {
        [_launchItem setState:NSOnState];
    }
    [popupMenu addItem:_launchItem];
    
    [popupMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quit)
                                               keyEquivalent:@""];
    [quitItem setTarget:self];
    [popupMenu addItem:quitItem];
}

- (void)toggleNumLock
{
    if(_enabled) {
        _enabled = NO;
        [_toggleItem setState:NSOffState];
        [_statusItem setImage:[NSImage imageNamed:@"disabled"]];

        [self stopNumLock];
        [self dismissAlert];
    }
    else {
        _enabled = YES;
        [_toggleItem setState:NSOnState];
        [_statusItem setImage:[NSImage imageNamed:@"enabled"]];
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self startNumLock];
        });
        [self showAlert];
    }
}

- (void)quit
{
	[[NSApplication sharedApplication] terminate:nil];
}

#pragma mark - Intercepting keyboard events

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
//    NSLog(@"%lld", CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));
    if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x20) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x15);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x22) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x17);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x1f) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x16);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x26) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x12);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x28) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x13);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x25) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x14);
    }
    else if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 0x2e) {
        CGEventSetIntegerValueField(event, kCGKeyboardEventKeycode, 0x1d);
    }
    
    return event;
}

- (void)startNumLock
{
    @autoreleasepool {
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, kCGEventMaskForAllEvents, myCGEventCallback, NULL);
        
        if(!_eventTap) {
            exit(1);
        }
        
        _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, kCFRunLoopCommonModes);
        
        CGEventTapEnable(_eventTap, true);
        
        CFRunLoopRun();
    }
}

- (void)stopNumLock
{
    CGEventTapEnable(_eventTap, false);
    CFRelease(_eventTap);
    CFRelease(_runLoopSource);
}

- (void)showAlert
{
    [_alertTimer invalidate];
    [_alertWindow close];
    
    _alertController = [[NSWindowController alloc] initWithWindowNibName:@"NLAlertWindow"];
    _alertWindow = [_alertController window];
    [_alertWindow setBackgroundColor:[NSColor clearColor]];
    [_alertWindow setOpaque:NO];
    [_alertWindow setStyleMask:NSBorderlessWindowMask];
    [_alertWindow setLevel:NSFloatingWindowLevel];
    [_alertWindow setIgnoresMouseEvents:YES];
    [_alertWindow makeKeyAndOrderFront:nil];
    
    _alertTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                   target:self
                                                 selector:@selector(dismissAlert)
                                                 userInfo:nil
                                                  repeats:NO];
}

- (void)dismissAlert
{
    [[_alertWindow animator] setAlphaValue:0.0];
    [_alertTimer invalidate];
    _alertTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                   target:_alertWindow
                                                 selector:@selector(close)
                                                 userInfo:nil
                                                  repeats:NO];
}

#pragma mark - Launch on login

static NSString const *kLoginHelperBundleIdentifier = @"com.object-factory.NumLockHelper";

- (BOOL)launchOnLogin
{
    NSArray *jobs = (__bridge NSArray *)SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    if (jobs == nil) {
        return NO;
    }
    
    if ([jobs count] == 0) {
        CFRelease((__bridge CFArrayRef)jobs);
        return NO;
    }
    
    BOOL onDemand = NO;
    for (NSDictionary *job in jobs) {
        if ([kLoginHelperBundleIdentifier isEqualToString:[job objectForKey:@"Label"]]) {
            onDemand = [[job objectForKey:@"OnDemand"] boolValue];
            break;
        }
    }
    
    CFRelease((__bridge CFArrayRef)jobs);
    return onDemand;
}

- (void)addLoginItem
{
    if(!SMLoginItemSetEnabled((__bridge CFStringRef)kLoginHelperBundleIdentifier, true)) {
        NSLog(@"SMLoginItemSetEnabled(..., true) failed");
    }
    else {
        [_launchItem setState:NSOnState];
    }
}

- (void)removeLoginItem
{
    if(!SMLoginItemSetEnabled((__bridge CFStringRef)kLoginHelperBundleIdentifier, false)) {
        NSLog(@"SMLoginItemSetEnabled(..., false) failed");
    }
    else {
        [_launchItem setState:NSOffState];
    }
}

- (void)setLaunchOnLogin:(BOOL)value
{
    if(!value) {
        [self removeLoginItem];
    }
    else {
        [self addLoginItem];
    }
}

- (void)toggleLaunchOnLogin
{
    if([self launchOnLogin]) {
        [self removeLoginItem];
    }
    else {
        [self addLoginItem];
    }
}


@end