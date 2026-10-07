//
//  apply.m
//  Mousecape
//
//  Created by Alex Zielenski on 2/1/14.
//  Copyright (c) 2014 Alex Zielenski. All rights reserved.
//

#import "apply.h"
#import "create.h"
#import "backup.h"
#import "restore.h"
#import "MCPrefs.h"
#import "NSBitmapImageRep+ColorSpace.h"

static BOOL validateCursorDictionary(NSDictionary *cursor, NSString *identifier, NSError **error);
static BOOL verifyCursorDictionary(NSDictionary *cursor, NSString *identifier);

static BOOL cursorGeometryMatches(CGSize a, CGPoint aHotSpot, NSUInteger aFrames, CGSize b, CGPoint bHotSpot, NSUInteger bFrames) {
    return fabs(a.width - b.width) < 0.5 && fabs(a.height - b.height) < 0.5 &&
        fabs(aHotSpot.x - bHotSpot.x) < 0.5 && fabs(aHotSpot.y - bHotSpot.y) < 0.5 &&
        aFrames == bFrames;
}

// Reads the cursor back to check the WindowServer took it; if it can't be read, assume it applied as older systems always did
static MCApplyResult verifyRegisteredCursor(char *identifier, CGSize size, CGPoint hotSpot, NSUInteger frameCount) {
    CGSize registeredSize = CGSizeZero;
    CGPoint registeredHotSpot = CGPointZero;
    NSUInteger registeredFrameCount = 0;
    CGFloat registeredFrameDuration = 0;
    CFArrayRef registeredImages = NULL;
    CGError err = CGSCopyRegisteredCursorImages(CGSMainConnectionID(), identifier, &registeredSize, &registeredHotSpot, &registeredFrameCount, &registeredFrameDuration, &registeredImages);
    if (registeredImages)
        CFRelease(registeredImages);

    if (err != kCGErrorSuccess)
        return MCApplyResultApplied;

    return cursorGeometryMatches(size, hotSpot, frameCount, registeredSize, registeredHotSpot, registeredFrameCount) ? MCApplyResultApplied : MCApplyResultIgnoredBySystem;
}

MCApplyResult applyCursorForIdentifier(NSUInteger frameCount, CGFloat frameDuration, CGPoint hotSpot, CGSize size, NSArray *images, NSString *ident, NSUInteger repeatCount) {
    if (frameCount > 256 || frameCount < 1) {
        MMLog(BOLD RED "Frame count of %s out of range [1...256]", ident.UTF8String);
        return MCApplyResultFailed;
    }

    char *idenfifier = (char *)ident.UTF8String;
    // Since macOS 27 the seed is never written, so it is only passed because the call requires it
    int seed = 0;
    CGError err = CGSRegisterCursorWithImages(CGSMainConnectionID(),
                                              idenfifier,
                                              true,
                                              true,
                                              size,
                                              hotSpot,
                                              frameCount,
                                              frameDuration,
                                              (__bridge CFArrayRef)images,
                                              &seed);
    
    if (err != kCGErrorSuccess) {
        MMLog(BOLD RED "CGSRegisterCursorWithImages failed for %s: CGError %d" RESET,
              ident.UTF8String, err);
        return MCApplyResultFailed;
    }

    // A success code no longer means the cursor changed, so check what the WindowServer holds
    return verifyRegisteredCursor(idenfifier, size, hotSpot, frameCount);
}

MCApplyResult applyCapeForIdentifier(NSDictionary *cursor, NSString *identifier, BOOL restore) {
    if (!cursor || !identifier) {
        NSLog(@"bad seed");
        return MCApplyResultFailed;
    }

    BOOL lefty = MCFlag(MCPreferencesHandednessKey);
    BOOL pointer = MCCursorIsPointer(identifier);
    NSNumber *frameCount    = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = cursor[MCCursorDictionaryFrameDuratiomKey];
    //    NSNumber *repeatCount   = cursor[MCCursorDictionaryRepeatCountKey];
    
    CGPoint hotSpot         = CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]);
    CGSize size             = CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]);
    NSArray *reps           = cursor[MCCursorDictionaryRepresentationsKey];
    NSMutableArray *images  = [NSMutableArray array];

    if (lefty && !restore && pointer) {
        MMLog("Lefty mode for %s", identifier.UTF8String);
        hotSpot.x = size.width - hotSpot.x - 1;
    }

    for (id object in reps) {
        CFTypeID type = CFGetTypeID((__bridge CFTypeRef)object);
        NSBitmapImageRep *rep;
        if (type == CGImageGetTypeID()) {
            rep = [[[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object] autorelease];
        } else {
            rep = [[[NSBitmapImageRep alloc] initWithData:object] autorelease];
        }
        rep = rep.retaggedSRGBSpace;

        if (!lefty || restore || !pointer) {
            // special case if array has a type of CGImage already there is no need to convert it
            if (type == CGImageGetTypeID()) {
                images[images.count] = object;
                continue;
            }
            
            images[images.count] = (__bridge id)[rep CGImage];
            
        } else {
            NSBitmapImageRep *newRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:rep.pixelsWide
                                                                               pixelsHigh:rep.pixelsHigh
                                                                            bitsPerSample:8
                                                                          samplesPerPixel:4
                                                                                 hasAlpha:YES
                                                                                 isPlanar:NO
                                                                           colorSpaceName:NSCalibratedRGBColorSpace
                                                                              bytesPerRow:4 * rep.pixelsWide
                                                                             bitsPerPixel:32] autorelease];
            NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:newRep];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:ctx];
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:rep.pixelsWide yBy:0];
            [transform scaleXBy:-1 yBy:1];
            [transform concat];

            [rep drawInRect:NSMakeRect(0, 0, rep.pixelsWide, rep.pixelsHigh)
                   fromRect:NSZeroRect
                  operation:NSCompositingOperationSourceOver
                   fraction:1.0
             respectFlipped:NO
                      hints:nil];
            [NSGraphicsContext restoreGraphicsState];
            images[images.count] = (__bridge id)[newRep CGImage];
        }
    }
    
    return applyCursorForIdentifier(frameCount.unsignedIntegerValue, frameDuration.doubleValue, hotSpot, size, images, identifier, 0);
}

// ignoredIdentifiers, if given, receives the cursors the system kept its own images for
static BOOL applyCapeReportingIgnoredInternal(NSDictionary *dictionary, NSMutableArray *ignoredIdentifiers, BOOL persistPreference) {
    @autoreleasepool {
        NSDictionary *cursors = dictionary[MCCursorDictionaryCursorsKey];
        NSString *name = dictionary[MCCursorDictionaryCapeNameKey];
        NSNumber *version = dictionary[MCCursorDictionaryCapeVersionKey];
        
        if (persistPreference)
            resetAllCursors();
        else
            resetAllCursorsWithoutPreferenceChanges();
        backupAllCursors();
        
        MMLog("Applying cape: %s %.02f", name.UTF8String, version.floatValue);
        
        NSMutableArray *ignored = [NSMutableArray array];
        for (NSString *key in cursors) {
            NSDictionary *cape = cursors[key];
            MMLog("Hooking for %s", key.UTF8String);
            
            MCApplyResult result = applyCapeForIdentifier(cape, key, NO);
            if (result == MCApplyResultFailed) {
                MMLog(BOLD RED "Failed to hook identifier %s for some unknown reason. Bailing out..." RESET, key.UTF8String);
                return NO;
            }

            // Newer systems draw some cursors from another name, so apply the cursor there too unless the cape has its own
            NSString *alias = cursorAliases()[key];
            bool aliasRegistered = false;
            if (alias && cursors[alias] == nil)
                MCIsCursorRegistered(CGSMainConnectionID(), (char *)alias.UTF8String, &aliasRegistered);

            if (aliasRegistered) {
                MMLog("Hooking for %s", alias.UTF8String);
                MCApplyResult aliasResult = applyCapeForIdentifier(cape, alias, NO);
                if (aliasResult == MCApplyResultApplied)
                    result = MCApplyResultApplied;
                else
                    MMLog(YELLOW "Could not also apply %s as %s" RESET, key.UTF8String, alias.UTF8String);
            }

            if (result == MCApplyResultIgnoredBySystem) {
                MMLog(YELLOW "The system kept its own cursor for %s" RESET, key.UTF8String);
                [ignored addObject:nameForCursorIdentifier(key)];
                [ignoredIdentifiers addObject:key];
            }
        }
        
        if (persistPreference)
            MCSetDefault(dictionary[MCCursorDictionaryIdentifierKey], MCPreferencesAppliedCursorKey);
        
        if (ignored.count == 0) {
            MMLog(BOLD GREEN "Applied %s successfully!" RESET, name.UTF8String);
        } else {
            [ignored sortUsingSelector:@selector(compare:)];
            MMLog(BOLD YELLOW "Applied %lu of %lu cursors from %s. This version of macOS does not allow replacing: %s" RESET,
                  (unsigned long)(cursors.count - ignored.count), (unsigned long)cursors.count, name.UTF8String,
                  [ignored componentsJoinedByString:@", "].UTF8String);
        }
        
        return YES;
    }
}

BOOL applyCapeReportingIgnored(NSDictionary *dictionary, NSMutableArray *ignoredIdentifiers) {
    return applyCapeReportingIgnoredInternal(dictionary, ignoredIdentifiers, YES);
}

BOOL applyCape(NSDictionary *dictionary) {
    return applyCapeReportingIgnored(dictionary, nil);
}

BOOL applyCapeAtPathReportingIgnored(NSString *path, NSMutableArray *ignoredIdentifiers) {
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:path];
    if (cape)
        return applyCapeReportingIgnored(cape, ignoredIdentifiers);
    MMLog(BOLD RED "Could not find valid file at %s to apply" RESET, path.UTF8String);
    return NO;
}

BOOL applyCapeAtPath(NSString *path) {
    return applyCapeAtPathReportingIgnored(path, nil);
}

static NSDictionary *validatedPreparedCursorsAtPath(NSString *path, NSError **error) {
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:path];
    NSDictionary *cursors = cape[MCCursorDictionaryCursorsKey];
    if (![cursors isKindOfClass:[NSDictionary class]] ||
        !cursors[@"com.apple.coregraphics.ArrowS"] ||
        !cursors[@"com.apple.coregraphics.IBeamS"]) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Prepared cape is invalid or lacks ArrowS/IBeamS."}];
        return nil;
    }
    if (cursors.count > 128) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                     userInfo:@{NSLocalizedDescriptionKey:@"Prepared cape contains too many cursors."}];
        return nil;
    }
    NSArray *keys = [cursors.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *identifier in keys) {
        if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0 || identifier.length > 160 ||
            !validateCursorDictionary(cursors[identifier], identifier, error))
            return nil;
    }
    return cursors;
}

static BOOL registerPreparedCursors(NSDictionary *cursors, BOOL continueAfterFailure) {
    BOOL success = YES;
    for (NSString *identifier in [cursors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        // Prepared capes are exact images; do not apply Mousecape handedness preferences.
        MCApplyResult result = applyCapeForIdentifier(cursors[identifier], identifier, YES);
        if (result != MCApplyResultApplied) {
            MMLog(BOLD RED "Cursor %s was not applied; recovery is required" RESET, identifier.UTF8String);
            success = NO;
            if (!continueAfterFailure)
                return NO;
        }
    }
    return success;
}

BOOL applyCapeSessionAtPath(NSString *path, NSString *expectedPriorPath) {
    NSError *error = nil;
    NSDictionary *cursors = validatedPreparedCursorsAtPath(path, &error);
    NSDictionary *priorCursors = validatedPreparedCursorsAtPath(expectedPriorPath, &error);
    if (!cursors || !priorCursors ||
        ![[NSSet setWithArray:cursors.allKeys] isEqualToSet:[NSSet setWithArray:priorCursors.allKeys]]) {
        MMLog(BOLD RED "%s" RESET, (error.localizedDescription ?: @"Target and expected prior key sets differ.").UTF8String);
        return NO;
    }

    for (NSString *identifier in [cursors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSDictionary *current = capeWithIdentifier(identifier);
        if (!current || !validateCursorDictionary(current, identifier, &error)) {
            MMLog(BOLD RED "Current cursor %s is not readable; nothing changed" RESET, identifier.UTF8String);
            return NO;
        }
    }

    // Deliberately make the exact expected-state check the final operation
    // before the first target registration.
    if (!verifyCapeAtPath(expectedPriorPath)) {
        MMLog(BOLD RED "Current cursor state no longer matches expected prior cape; nothing changed" RESET);
        return NO;
    }
    return registerPreparedCursors(cursors, NO) && verifyCapeAtPath(path);
}

BOOL restoreCapeSessionAtPath(NSString *path) {
    NSError *error = nil;
    NSDictionary *cursors = validatedPreparedCursorsAtPath(path, &error);
    if (!cursors) {
        MMLog(BOLD RED "%s" RESET, error.localizedDescription.UTF8String);
        return NO;
    }
    // After logout/login, WindowServer may already have restored every native
    // cursor. Accept that exact state without re-registering animations that
    // Mousecape cannot round-trip, such as Apple's 30-frame Wait cursor.
    if (verifyCapeAtPath(path)) {
        MMLog(BOLD GREEN "Saved cursor state is already restored; no registration needed" RESET);
        return YES;
    }
    // Recovery is best effort across the complete saved key set. One rejected
    // cursor must not prevent later roles from being restored.
    registerPreparedCursors(cursors, YES);
    BOOL verified = verifyCapeAtPath(path);
    // Final exact state is authoritative. A registration may be refused while
    // that role already matches natively (notably the 30-frame Wait cursor).
    return verified;
}

static CGImageRef createProbeImage(size_t pixels) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, pixels, pixels, 8, 4 * pixels, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(ctx, 1, 0, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, pixels, pixels));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return image;
}

// Registers a test image for one cursor, reads it back, then puts the original back; returns -1 if it isn't registered
static NSInteger probeCursor(NSString *key, NSArray *probeImages) {
    char *identifier = (char *)key.UTF8String;
    CGSize size = CGSizeZero;
    CGPoint hotSpot = CGPointZero;
    NSUInteger frameCount = 0;
    CGFloat frameDuration = 0;
    CFArrayRef images = NULL;
    CGError err = CGSCopyRegisteredCursorImages(CGSMainConnectionID(), identifier, &size, &hotSpot, &frameCount, &frameDuration, &images);

    // Without the original there would be nothing to put back, so leave the cursor alone
    if (err != kCGErrorSuccess || !images || CFArrayGetCount(images) == 0) {
        if (images)
            CFRelease(images);
        return -1;
    }

    CGSize probeSize = CGSizeMake(32, 32);
    CGPoint probeHotSpot = CGPointMake(7, 9);
    if (cursorGeometryMatches(size, hotSpot, frameCount, probeSize, probeHotSpot, 1))
        probeHotSpot = CGPointMake(9, 7);

    MCApplyResult result = applyCursorForIdentifier(1, 0, probeHotSpot, probeSize, probeImages, key, 0);

    int seed = 0;
    CGSRegisterCursorWithImages(CGSMainConnectionID(), identifier, true, true, size, hotSpot, frameCount, frameDuration, images, &seed);
    if (verifyRegisteredCursor(identifier, size, hotSpot, frameCount) != MCApplyResultApplied)
        MMLog(BOLD RED "  Could not put the original %s back; logging out will reset it" RESET, key.UTF8String);
    CFRelease(images);

    return result;
}

// Reports which built-in cursors this system lets Mousecape replace, under their original or newer names
void probeCursorOverrides(void) {
    @autoreleasepool {
        CGImageRef probeImage = createProbeImage(64);
        NSArray *probeImages = @[ (__bridge id)probeImage ];
        NSUInteger blockedCount = 0;

        MMLog(BOLD "Probing which cursors this version of macOS lets Mousecape replace..." RESET);

        NSUInteger i = 0;
        NSString *key = nil;
        while ((key = defaultCursors[i++]) != nil) {
            NSInteger result = probeCursor(key, probeImages);
            NSString *alias = cursorAliases()[key];
            NSInteger aliasResult = alias ? probeCursor(alias, probeImages) : -1;

            const char *outcome;
            if (result == -1) {
                outcome = "not registered, skipped";
            } else if (result == MCApplyResultApplied) {
                outcome = GREEN "replaceable" RESET;
            } else if (aliasResult == MCApplyResultApplied) {
                outcome = GREEN "replaceable" RESET " (the system draws it from its newer name)";
            } else {
                outcome = result == MCApplyResultIgnoredBySystem ? YELLOW "kept by the system" RESET : RED "failed to register" RESET;
                blockedCount++;
            }
            MMLog("  %-12s %s", key.pathExtension.UTF8String, outcome);

            if (aliasResult != -1) {
                const char *aliasOutcome = aliasResult == MCApplyResultApplied ? GREEN "replaceable" RESET :
                    aliasResult == MCApplyResultIgnoredBySystem ? YELLOW "kept by the system" RESET : RED "failed to register" RESET;
                MMLog("    %-10s %s", alias.pathExtension.UTF8String, aliasOutcome);
            }
        }

        CGImageRelease(probeImage);
        if (blockedCount == 0)
            MMLog(BOLD GREEN "Every built-in cursor can be replaced on this system." RESET);
        else
            MMLog(BOLD "%lu built-in cursor(s) cannot be replaced on this system." RESET, (unsigned long)blockedCount);
    }
}

BOOL checkCursorReadback(void) {
    @autoreleasepool {
        NSArray *keys = @[ @"com.apple.coregraphics.Arrow",
                           @"com.apple.coregraphics.ArrowS",
                           @"com.apple.coregraphics.IBeam",
                           @"com.apple.coregraphics.IBeamS" ];
        BOOL ok = YES;

        MMLog(BOLD "Checking macOS cursor readback without changing cursors..." RESET);
        for (NSString *key in keys) {
            CGSize size = CGSizeZero;
            CGPoint hotSpot = CGPointZero;
            NSUInteger frameCount = 0;
            CGFloat frameDuration = 0;
            CFArrayRef images = NULL;
            CGError error = CGSCopyRegisteredCursorImages(CGSMainConnectionID(),
                                                          (char *)key.UTF8String,
                                                          &size,
                                                          &hotSpot,
                                                          &frameCount,
                                                          &frameDuration,
                                                          &images);
            CFIndex imageCount = images ? CFArrayGetCount(images) : 0;
            if (error == kCGErrorSuccess && imageCount > 0 && frameCount > 0) {
                MMLog("  %-10s readable: %lux%lu, %lu frame(s), hotspot %.1f,%.1f",
                      key.pathExtension.UTF8String,
                      (unsigned long)size.width, (unsigned long)size.height,
                      (unsigned long)frameCount, hotSpot.x, hotSpot.y);
            } else {
                MMLog(BOLD RED "  %s unavailable: CGError %d, %ld image(s), %lu frame(s)" RESET,
                      key.pathExtension.UTF8String, error, (long)imageCount,
                      (unsigned long)frameCount);
                ok = NO;
            }
            if (images)
                CFRelease(images);
        }
        return ok;
    }
}

static NSData *normalizedPixels(CGImageRef image) {
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, width, height, 8, width * 4,
                                                 colorSpace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (!context)
        return nil;
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    return data;
}

static BOOL cursorImagesMatch(NSArray *expected, CFArrayRef actual) {
    if (!actual || expected.count != (NSUInteger)CFArrayGetCount(actual))
        return NO;

    for (NSUInteger index = 0; index < expected.count; index++) {
        id object = expected[index];
        NSBitmapImageRep *representation = nil;
        if (CFGetTypeID((__bridge CFTypeRef)object) == CGImageGetTypeID())
            representation = [[[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object] autorelease];
        else
            representation = [[[NSBitmapImageRep alloc] initWithData:object] autorelease];
        CGImageRef expectedImage = representation.CGImage;
        if (!expectedImage)
            return NO;

        CGImageRef actualImage = (CGImageRef)CFArrayGetValueAtIndex(actual, index);
        if (CGImageGetWidth(expectedImage) != CGImageGetWidth(actualImage) ||
            CGImageGetHeight(expectedImage) != CGImageGetHeight(actualImage) ||
            ![normalizedPixels(expectedImage) isEqualToData:normalizedPixels(actualImage)])
            return NO;
    }
    return YES;
}

static BOOL validateCursorDictionary(NSDictionary *cursor, NSString *identifier, NSError **error) {
    NSArray *required = @[ MCCursorDictionaryFrameCountKey, MCCursorDictionaryFrameDuratiomKey,
                           MCCursorDictionaryHotSpotXKey, MCCursorDictionaryHotSpotYKey,
                           MCCursorDictionaryPointsWideKey, MCCursorDictionaryPointsHighKey,
                           MCCursorDictionaryRepresentationsKey ];
    for (NSString *key in required) {
        if (!cursor[key]) {
            if (error)
                *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Cursor %@ lacks %@.", identifier, key]}];
            return NO;
        }
    }
    NSNumber *frameNumber = cursor[MCCursorDictionaryFrameCountKey];
    NSNumber *durationNumber = cursor[MCCursorDictionaryFrameDuratiomKey];
    NSNumber *widthNumber = cursor[MCCursorDictionaryPointsWideKey];
    NSNumber *heightNumber = cursor[MCCursorDictionaryPointsHighKey];
    NSNumber *hotXNumber = cursor[MCCursorDictionaryHotSpotXKey];
    NSNumber *hotYNumber = cursor[MCCursorDictionaryHotSpotYKey];
    NSArray *numbers = @[ frameNumber, durationNumber, widthNumber, heightNumber, hotXNumber, hotYNumber ];
    for (id number in numbers) {
        if (![number isKindOfClass:[NSNumber class]] || !isfinite([number doubleValue])) {
            if (error)
                *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Cursor %@ has a non-finite numeric field.", identifier]}];
            return NO;
        }
    }
    double frameValue = frameNumber.doubleValue;
    NSUInteger frameCount = frameNumber.unsignedIntegerValue;
    CGFloat frameDuration = durationNumber.doubleValue;
    CGFloat width = widthNumber.doubleValue;
    CGFloat height = heightNumber.doubleValue;
    CGFloat hotX = hotXNumber.doubleValue;
    CGFloat hotY = hotYNumber.doubleValue;
    NSArray *representations = cursor[MCCursorDictionaryRepresentationsKey];
    if (frameValue != floor(frameValue) || frameCount < 1 || frameCount > 256 ||
        frameDuration < 0 || width <= 0 || height <= 0 || width > 512 || height > 512 ||
        hotX < 0 || hotY < 0 || hotX >= width || hotY >= height ||
        ![representations isKindOfClass:[NSArray class]] ||
        representations.count == 0 || representations.count > 8) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Cursor %@ has invalid geometry or representations.", identifier]}];
        return NO;
    }
    NSUInteger totalEncodedBytes = 0;
    for (id object in representations) {
        NSBitmapImageRep *representation = nil;
        if (CFGetTypeID((__bridge CFTypeRef)object) == CGImageGetTypeID())
            representation = [[[NSBitmapImageRep alloc] initWithCGImage:(__bridge CGImageRef)object] autorelease];
        else if ([object isKindOfClass:[NSData class]])
            representation = [[[NSBitmapImageRep alloc] initWithData:object] autorelease];
        if ([object isKindOfClass:[NSData class]]) {
            if ([(NSData *)object length] > 32 * 1024 * 1024 ||
                totalEncodedBytes > 64 * 1024 * 1024 - [(NSData *)object length]) {
                if (error)
                    *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                             userInfo:@{NSLocalizedDescriptionKey:
                                                            [NSString stringWithFormat:@"Cursor %@ image data exceeds safety limits.", identifier]}];
                return NO;
            }
            totalEncodedBytes += [(NSData *)object length];
        }
        CGImageRef image = representation.CGImage;
        size_t pixelsWide = image ? CGImageGetWidth(image) : 0;
        size_t pixelsHigh = image ? CGImageGetHeight(image) : 0;
        if (!image || pixelsWide == 0 || pixelsHigh == 0 ||
            pixelsWide > 8192 || pixelsHigh > 8192 ||
            pixelsWide > (64 * 1024 * 1024) / pixelsHigh ||
            pixelsHigh % frameCount != 0) {
            if (error)
                *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Cursor %@ contains unreadable image data.", identifier]}];
            return NO;
        }
        // Each representation is one resolution. Animated frames are stacked
        // vertically inside that representation; representation count is
        // independent of frame count.
        CGFloat scaleX = pixelsWide / width;
        CGFloat scaleY = (pixelsHigh / frameCount) / height;
        if (!isfinite(scaleX) || !isfinite(scaleY) || scaleX < 0.25 || scaleX > 16 ||
            fabs(scaleX - scaleY) > 0.01) {
            if (error)
                *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Cursor %@ representation does not match frame geometry.", identifier]}];
            return NO;
        }
    }
    return YES;
}

static BOOL verifyCursorDictionary(NSDictionary *cursor, NSString *identifier) {
    CGSize size = CGSizeZero;
    CGPoint hotSpot = CGPointZero;
    NSUInteger frameCount = 0;
    CGFloat frameDuration = 0;
    CFArrayRef images = NULL;
    CGError error = CGSCopyRegisteredCursorImages(CGSMainConnectionID(),
                                                  (char *)identifier.UTF8String,
                                                  &size, &hotSpot, &frameCount,
                                                  &frameDuration, &images);
    BOOL geometryMatches = error == kCGErrorSuccess &&
        cursorGeometryMatches(size, hotSpot, frameCount,
                              CGSizeMake([cursor[MCCursorDictionaryPointsWideKey] doubleValue],
                                         [cursor[MCCursorDictionaryPointsHighKey] doubleValue]),
                              CGPointMake([cursor[MCCursorDictionaryHotSpotXKey] doubleValue],
                                          [cursor[MCCursorDictionaryHotSpotYKey] doubleValue]),
                              [cursor[MCCursorDictionaryFrameCountKey] unsignedIntegerValue]) &&
        fabs(frameDuration - [cursor[MCCursorDictionaryFrameDuratiomKey] doubleValue]) < 0.0001;
    BOOL imagesMatch = geometryMatches && cursorImagesMatch(cursor[MCCursorDictionaryRepresentationsKey], images);
    if (images)
        CFRelease(images);
    MMLog("  %-10s %s", identifier.pathExtension.UTF8String,
          imagesMatch ? GREEN "matches" RESET : RED "does not match" RESET);
    return imagesMatch;
}

BOOL verifyCapeAtPath(NSString *path) {
    NSDictionary *cape = [NSDictionary dictionaryWithContentsOfFile:path];
    NSDictionary *cursors = cape[MCCursorDictionaryCursorsKey];
    if (![cursors isKindOfClass:[NSDictionary class]] || cursors.count == 0 || cursors.count > 128) {
        MMLog(BOLD RED "Invalid cape at %s" RESET, path.UTF8String);
        return NO;
    }

    if (!cursors[@"com.apple.coregraphics.ArrowS"] || !cursors[@"com.apple.coregraphics.IBeamS"]) {
        MMLog(BOLD RED "Cape lacks effective ArrowS or IBeamS cursor data" RESET);
        return NO;
    }

    MMLog(BOLD "Verifying every cursor in prepared cape..." RESET);
    BOOL success = YES;
    for (NSString *identifier in [cursors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSError *error = nil;
        if (!validateCursorDictionary(cursors[identifier], identifier, &error) ||
            !verifyCursorDictionary(cursors[identifier], identifier))
            success = NO;
    }
    return success;
}

static NSData *capeDataWithCursors(NSDictionary *template, NSDictionary *cursors,
                                   NSString *name, NSString *identifier, NSError **error) {
    NSMutableDictionary *cape = template ? [[template mutableCopy] autorelease] : [NSMutableDictionary dictionary];
    cape[MCCursorDictionaryAuthorKey] = cape[MCCursorDictionaryAuthorKey] ?: @"Local cursor recovery";
    cape[MCCursorDictionaryCapeNameKey] = name;
    cape[MCCursorDictionaryCapeVersionKey] = @1.0;
    cape[MCCursorDictionaryCloudKey] = @NO;
    cape[MCCursorDictionaryCursorsKey] = cursors;
    cape[MCCursorDictionaryHiDPIKey] = @YES;
    cape[MCCursorDictionaryIdentifierKey] = identifier;
    cape[MCCursorDictionaryVersionKey] = @(MCCursorCreatorVersion);
    cape[MCCursorDictionaryMinimumVersionKey] = @(MCCursorParserVersion);
    return [NSPropertyListSerialization dataWithPropertyList:cape
                                                      format:NSPropertyListBinaryFormat_v1_0
                                                     options:0 error:error];
}

static BOOL installPreparedFiles(NSData *preparedData, NSString *preparedPath,
                                 NSData *priorData, NSString *priorPath, NSError **error) {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:preparedPath] || [manager fileExistsAtPath:priorPath]) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorWriteFailCode
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Prepared or prior cape already exists; refusing to overwrite recovery state."}];
        return NO;
    }
    NSString *token = UUID();
    NSString *preparedTemp = [[preparedPath stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:[NSString stringWithFormat:@".prepared-%@.tmp", token]];
    NSString *priorTemp = [[priorPath stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:[NSString stringWithFormat:@".prior-%@.tmp", token]];
    BOOL preparedInstalled = NO;
    @try {
        if (![preparedData writeToFile:preparedTemp options:NSDataWritingAtomic error:error] ||
            ![priorData writeToFile:priorTemp options:NSDataWritingAtomic error:error] ||
            ![manager setAttributes:@{NSFilePosixPermissions: @0600} ofItemAtPath:preparedTemp error:error] ||
            ![manager setAttributes:@{NSFilePosixPermissions: @0600} ofItemAtPath:priorTemp error:error] ||
            ![manager moveItemAtPath:preparedTemp toPath:preparedPath error:error])
            return NO;
        preparedInstalled = YES;
        if (![manager moveItemAtPath:priorTemp toPath:priorPath error:error]) {
            [manager removeItemAtPath:preparedPath error:nil];
            preparedInstalled = NO;
            return NO;
        }
        return YES;
    } @finally {
        if ([manager fileExistsAtPath:preparedTemp])
            [manager removeItemAtPath:preparedTemp error:nil];
        if ([manager fileExistsAtPath:priorTemp])
            [manager removeItemAtPath:priorTemp error:nil];
        if (preparedInstalled && ![manager fileExistsAtPath:priorPath])
            [manager removeItemAtPath:preparedPath error:nil];
    }
}

BOOL prepareSessionCapes(NSString *targetPath, NSString *preparedPath,
                         NSString *priorPath, NSError **error) {
    NSDictionary *target = [NSDictionary dictionaryWithContentsOfFile:targetPath];
    NSDictionary *targetCursors = target[MCCursorDictionaryCursorsKey];
    if (![targetCursors isKindOfClass:[NSDictionary class]] ||
        !targetCursors[@"com.apple.coregraphics.ArrowS"] ||
        !targetCursors[@"com.apple.coregraphics.IBeamS"]) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Target cape must contain ArrowS and IBeamS."}];
        return NO;
    }

    NSSet *legacyAliases = [NSSet setWithArray:@[ @"com.apple.coregraphics.Arrow",
                                                  @"com.apple.coregraphics.IBeam" ]];
    NSMutableDictionary *preparedCursors = [NSMutableDictionary dictionary];
    NSMutableDictionary *priorCursors = [NSMutableDictionary dictionary];
    for (NSString *identifier in [targetCursors.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([legacyAliases containsObject:identifier])
            continue;
        if (!validateCursorDictionary(targetCursors[identifier], identifier, error))
            return NO;
        NSDictionary *current = processedCapeWithIdentifier(identifier);
        if (!current)
            continue;
        if (!validateCursorDictionary(current, identifier, error))
            return NO;
        NSUInteger targetFrameCount = [targetCursors[identifier][MCCursorDictionaryFrameCountKey] unsignedIntegerValue];
        NSUInteger priorFrameCount = [current[MCCursorDictionaryFrameCountKey] unsignedIntegerValue];
        if (targetFrameCount > 24 || priorFrameCount > 24) {
            MMLog(YELLOW "Skipping %s: Mousecape cannot reliably register more than 24 frames" RESET,
                  identifier.UTF8String);
            continue;
        }
        preparedCursors[identifier] = targetCursors[identifier];
        priorCursors[identifier] = current;
    }

    if (!preparedCursors[@"com.apple.coregraphics.ArrowS"] ||
        !preparedCursors[@"com.apple.coregraphics.IBeamS"] ||
        ![[NSSet setWithArray:preparedCursors.allKeys] isEqualToSet:[NSSet setWithArray:priorCursors.allKeys]]) {
        if (error)
            *error = [NSError errorWithDomain:MCErrorDomain code:MCErrorInvalidFormatCode
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Readable ArrowS/IBeamS and an exact recovery key set are required."}];
        return NO;
    }

    NSData *preparedData = capeDataWithCursors(target, preparedCursors,
                                               @"Celeste Pixel Prepared",
                                               @"com.kianconti.celeste-pixel.prepared", error);
    NSData *priorData = capeDataWithCursors(nil, priorCursors,
                                            @"Pre-Celeste Cursor Snapshot",
                                            @"com.kianconti.celeste-pixel.prior", error);
    if (!preparedData || !priorData)
        return NO;

    NSDictionary *preparedCheck = [NSPropertyListSerialization propertyListWithData:preparedData options:0 format:NULL error:error];
    NSDictionary *priorCheck = [NSPropertyListSerialization propertyListWithData:priorData options:0 format:NULL error:error];
    NSSet *preparedKeys = [NSSet setWithArray:[preparedCheck[MCCursorDictionaryCursorsKey] allKeys]];
    NSSet *priorKeys = [NSSet setWithArray:[priorCheck[MCCursorDictionaryCursorsKey] allKeys]];
    if (!preparedCheck || !priorCheck || ![preparedKeys isEqualToSet:priorKeys])
        return NO;
    return installPreparedFiles(preparedData, preparedPath, priorData, priorPath, error);
}
