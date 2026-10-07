//
//  apply.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_apply_h
#define Mousecape_apply_h

// MCApplyResultFailed is zero so callers that treat the result as a BOOL keep working
typedef NS_ENUM(NSInteger, MCApplyResult) {
    MCApplyResultFailed = 0,
    MCApplyResultApplied = 1,
    // The system reported success but kept its own cursor (macOS 27 does this for the Arrow and IBeam names)
    MCApplyResultIgnoredBySystem = 2
};

extern MCApplyResult applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount);
extern MCApplyResult applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore);
extern BOOL applyCape(NSDictionary *dictionary);
extern BOOL applyCapeReportingIgnored(NSDictionary *dictionary, NSMutableArray *ignoredIdentifiers);
extern BOOL applyCapeAtPath(NSString *path);
/// Applies only explicit keys from a prepared cape without global reset,
/// WindowServer backup aliases, or Mousecape preference changes.
extern BOOL applyCapeSessionAtPath(NSString *path, NSString *expectedPriorPath);
/// Recovery path: validates saved data, registers only saved keys, then verifies
/// every key. Current registrations may be unreadable.
extern BOOL restoreCapeSessionAtPath(NSString *path);
/// Builds matching target and recovery capes from the intersection of target
/// keys and currently readable cursor registrations. No cursor is changed.
extern BOOL prepareSessionCapes(NSString *targetPath, NSString *preparedPath,
                                NSString *priorPath, NSError **error);
extern BOOL applyCapeAtPathReportingIgnored(NSString *path, NSMutableArray *ignoredIdentifiers);
extern void probeCursorOverrides(void);
/// Read-only runtime check: confirms cursor images can be read under the names
/// macOS 27 uses. Never registers, removes, or persists a cursor.
extern BOOL checkCursorReadback(void);
/// Read-only exact comparison of every registration in a prepared cape.
extern BOOL verifyCapeAtPath(NSString *path);

#endif
