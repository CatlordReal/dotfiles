//
//  create.h
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#ifndef Mousecape_create_h
#define Mousecape_create_h
extern NSError *createCape(NSString *input, NSString *output, BOOL convert);

extern NSDictionary *processedCapeWithIdentifier(NSString *identifier);
extern BOOL dumpCursorsToFile(NSString *path, BOOL (^progress)(NSUInteger current, NSUInteger total));
/// Captures registered cursors through copy APIs only. Does not hide, resize,
/// select, register, or remove cursors. Writes an atomic binary plist, mode 0600.
extern BOOL dumpCursorsSafelyToFile(NSString *path, NSError **error);
extern BOOL dumpCursorsToFolder(NSString *path, BOOL (^progress)(NSUInteger current, NSUInteger total));

extern NSDictionary *createCapeFromDirectory(NSString *path);
extern NSDictionary *createCapeFromMightyMouse(NSDictionary *mightyMouse, NSDictionary *metadata);

extern void exportCape(NSDictionary *cape, NSString *destination);

#endif
