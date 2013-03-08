//
//  NLAppDelegate.m
//  NumLock
//
//  Created by Christian A. Strømmen on 07.03.13.
//  Copyright (c) 2013 Object Factory. All rights reserved.
//

#import "NLAppDelegate.h"
#import "NLMenulet.h"

@interface NLAppDelegate ()

@property (nonatomic, strong) NLMenulet *menulet;
@property (nonatomic, assign) BOOL launchOnLogin;

@end

@implementation NLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self readSettings];
    
    if(!_menulet) {
        _menulet = [[NLMenulet alloc] init];
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self saveSettings];
}

# pragma mark - Settings

- (void)saveSettings
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:_menulet
                    forKey:@"menulet"];
    [archiver finishEncoding];
    
    [[NSUserDefaults standardUserDefaults] setObject:data
                                              forKey:@"menulet"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)readSettings
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"menulet"];
    
    if(data) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        _menulet = [unarchiver decodeObjectForKey:@"menulet"];
        [unarchiver finishDecoding];
    }
}

@end
