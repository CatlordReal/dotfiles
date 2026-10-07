//
//  backup.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "backup.h"
#import "apply.h"

NSString *backupStringForIdentifier(NSString *identifier) {
    return [NSString stringWithFormat:@"com.alexzielenski.mousecape.%@", identifier];
}

void backupCursorForIdentifier(NSString *ident) {
    bool registered = false;
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)ident.UTF8String, &registered);
    
//     dont try to backup a nonexistant cursor
    if (!registered)
        return;
    
    NSString *backupIdent = backupStringForIdentifier(ident);
    MCIsCursorRegistered(CGSMainConnectionID(), (char *)backupIdent.UTF8String, &registered);
    
//     don't re-back it up
    if (registered)
        return;
    
    NSDictionary *cape = capeWithIdentifier(ident);
    (void)applyCapeForIdentifier(cape, backupIdent, YES);
    
}

void backupAllCursors() {
    // Check each cursor on its own: one registered after the Arrow backup was made would never get a backup, and since macOS 27 reset cannot remove it
    NSUInteger i = 0;
    NSString *key = nil;
    while ((key = defaultCursors[i]) != nil) {
        backupCursorForIdentifier(key);
        i++;
    }

    // Skipped automatically on systems that don't register these names
    for (NSString *alias in cursorAliases().allValues) {
        backupCursorForIdentifier(alias);
    }
    // no need to backup core cursors
    
}