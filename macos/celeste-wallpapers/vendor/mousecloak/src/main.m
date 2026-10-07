//
//  main.m
//  mousecloak
//
//  Created by Alex Zielenski on 2/11/13.
//  Copyright (c) 2013 Alex Zielenski. All rights reserved.
//

#import "restore.h"
#import "backup.h"
#import "apply.h"
#import "create.h"
#import "listen.h"
#import "scale.h"

#import <GBCli/GBSettings.h>
#import <GBCli/GBOptionsHelper.h>
#import <GBCli/GBCommandLineParser.h>

@interface GBOptionsHelper (Helper)
- (void)replacePlaceholdersAndPrintStringFromBlock:(GBOptionStringBlock)block;
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        GBSettings *settings = [GBSettings settingsWithName:@"mousecape" parent:nil];
        
        GBOptionsHelper *options = [[[GBOptionsHelper alloc] init] autorelease];
        [options registerSeparator:@(BOLD "APPLYING CAPES" RESET)];
        [options registerOption:'a' long:@"apply" description:@"Apply a cape" flags:GBValueRequired];
        [options registerOption:'r' long:@"reset" description:@"Reset to the default OSX cursors" flags:GBValueNone];
        [options registerOption:0 long:@"apply-session" description:@"Apply prepared cape only if current state matches --expect" flags:GBValueRequired];
        [options registerOption:0 long:@"expect" description:@"Expected current prior cape paired with --apply-session" flags:GBValueRequired];
        [options registerOption:0 long:@"restore-session" description:@"Restore explicit saved keys without global reset" flags:GBValueRequired];
        [options registerOption:0 long:@"prepare" description:@"Read-only prepare target and exact prior capes" flags:GBValueRequired];
        [options registerOption:0 long:@"prepared" description:@"Output path paired with --prepare" flags:GBValueRequired];
        [options registerOption:0 long:@"prior" description:@"Recovery output path paired with --prepare" flags:GBValueRequired];
        [options registerSeparator:@(BOLD "CREATING CAPES" RESET)];
        [options registerOption:'c' long:@"create"
                    description:
         @"Create a cursor from a folder. Default output is to a new file of the same name. Directory must use the format:\n"
         "\t\t├── com.apple.coregraphics.Arrow\n"
         "\t\t│   ├── 0.png\n"
         "\t\t│   ├── 1.png\n"
         "\t\t│   ├── 2.png\n"
         "\t\t│   └── 3.png\n"
         "\t\t├── com.apple.coregraphics.Wait\n"
         "\t\t│   ├── 0.png\n"
         "\t\t│   ├── 1.png\n"
         "\t\t│   └── 2.png\n"
         "\t\t├── com.apple.cursor.3\n"
         "\t\t│   ├── 0.png\n"
         "\t\t│   ├── 1.png\n"
         "\t\t│   ├── 2.png\n"
         "\t\t│   └── 3.png\n"
         "\t\t└── com.apple.cursor.5\n"
         "\t\t    ├── 0.png\n"
         "\t\t    ├── 1.png\n"
         "\t\t    ├── 2.png\n"
         "\t\t    └── 3.png\n"
                          flags:GBValueRequired];
        [options registerOption:'d' long:@"dump" description:@"Dumps the currently applied cursors to a file." flags:GBValueRequired];
        [options registerOption:0 long:@"dump-safe" description:@"Atomically snapshot cursors without changing cursor state" flags:GBValueRequired];
        [options registerSeparator:@(BOLD "CONVERTING MIGHTYMOUSE TO CAPE" RESET)];
        [options registerOption:'x' long:@"convert" description:@"Convert a .MightyMouse file to cape. Default output is to a new file of the same name" flags:GBValueRequired];
        [options registerSeparator:@(BOLD "MISCELLANEOUS" RESET)];
        [options registerOption:'e' long:@"export" description:@"Export a cape to a directory" flags:GBValueRequired];
        [options registerOption:'p' long:@"probe" description:@"Check which built-in cursors this version of macOS lets Mousecape replace" flags:GBValueNone];
        [options registerOption:0 long:@"check-readback" description:@"Read-only check for macOS 27 ArrowS/IBeamS cursor access" flags:GBValueNone];
        [options registerOption:0 long:@"verify" description:@"Read-only compare every cursor with a prepared cape" flags:GBValueRequired];
        [options registerOption:'?' long:@"help" description:@"Display this help and exit" flags:GBValueNone];
        [options registerOption:'o' long:@"output" description:@"Use this option to tell where an output file goes. (For convert, create, and export)" flags:GBValueRequired];
        [options registerOption:0 long:@"suppressCopyright" description:@"Suppress Copyright info" flags:GBValueNone | GBOptionNoHelp | GBOptionNoPrint];
        [options registerOption:'s' long:@"scale" description:@"Scale the cursor to obscene multipliers or get the current scale" flags:GBValueOptional];
        [options registerOption:0 long:@"listen" description:@"Keep mousecloak alive to apply the current Cape every user switch" flags:GBValueNone | GBOptionNoHelp | GBOptionNoPrint];
        
        options.applicationName = ^{ return @"mousecloak"; };
        options.applicationVersion = ^{ return @"2.0"; };
        options.applicationBuild = ^{ return @""; };
        options.printHelpHeader = ^{ return @(BOLD WHITE "%APPNAME v%APPVERSION" RESET); };
        options.printHelpFooter = ^{ return @(BOLD WHITE "Copyright © 2013-20 Alex Zielenski" RESET); };
        
        GBCommandLineParser *parser = [[[GBCommandLineParser alloc] init] autorelease];
        [options registerOptionsToCommandLineParser:parser];
        [parser parseOptionsWithArguments:argv count:argc block:^(GBParseFlags flags, NSString *option, id value, BOOL *stop) {
            switch (flags) {
                case GBParseFlagUnknownOption:
                    MMLog(BOLD RED "Unknown command line option %s, try --help!" RESET, option.UTF8String);
                    break;
                case GBParseFlagMissingValue:
                    MMLog(BOLD RED "Missing value for command line option %s, try --help!" RESET, option.UTF8String);
                    break;
                case GBParseFlagArgument:
                    [settings setObject:@YES forKey:value];
                    break;
                case GBParseFlagOption:
                    [settings setObject:value forKey:option];
                    break;
            }
        }];
        
        if ([settings boolForKey:@"help"] || argc == 1) {
            [options printHelp];
            return EXIT_SUCCESS;
        }
        
        BOOL suppressCopyright = [settings boolForKey:@"suppressCopyright"];
        
        if (!suppressCopyright)
            [options replacePlaceholdersAndPrintStringFromBlock:options.printHelpHeader];
        
        if ([settings boolForKey:@"reset"]) {
            // reset to default cursors
            BOOL success = resetAllCursors();
            
            if (!suppressCopyright)
                [options replacePlaceholdersAndPrintStringFromBlock:options.printHelpFooter];
            return success ? EXIT_SUCCESS : EXIT_FAILURE;
        }
        
        BOOL convert = [settings isKeyPresentAtThisLevel:@"convert"];
        BOOL apply   = [settings isKeyPresentAtThisLevel:@"apply"];
        BOOL applySession = [settings isKeyPresentAtThisLevel:@"apply-session"];
        BOOL restoreSession = [settings isKeyPresentAtThisLevel:@"restore-session"];
        BOOL prepare = [settings isKeyPresentAtThisLevel:@"prepare"];
        BOOL create  = [settings isKeyPresentAtThisLevel:@"create"];
        BOOL dump    = [settings isKeyPresentAtThisLevel:@"dump"];
        BOOL dumpSafe = [settings isKeyPresentAtThisLevel:@"dump-safe"];
        BOOL scale   = [settings isKeyPresentAtThisLevel:@"scale"];
        BOOL listen  = [settings isKeyPresentAtThisLevel:@"listen"];
        BOOL export  = [settings isKeyPresentAtThisLevel:@"export"];
        BOOL probe   = [settings isKeyPresentAtThisLevel:@"probe"];
        BOOL checkReadback = [settings isKeyPresentAtThisLevel:@"check-readback"];
        BOOL verify = [settings isKeyPresentAtThisLevel:@"verify"];
        int amt = 0;
        
        if (convert) amt++;
        if (apply) amt++;
        if (applySession) amt++;
        if (restoreSession) amt++;
        if (prepare) amt++;
        if (create) amt++;
        if (dump) amt++;
        if (dumpSafe) amt++;
        if (scale) amt++;
        if (listen) amt++;
        if (export) amt++;
        if (probe) amt++;
        if (checkReadback) amt++;
        if (verify) amt++;
        
        if (amt > 1) {
            MMLog(BOLD RED "One command at a time, son!" RESET);
            
            if (!suppressCopyright)
                [options replacePlaceholdersAndPrintStringFromBlock:options.printHelpFooter];
            return 0;
        }
        
        if (prepare) {
            NSString *prepared = [settings objectForKey:@"prepared"];
            NSString *prior = [settings objectForKey:@"prior"];
            if (!prepared || !prior) {
                MMLog(BOLD RED "--prepare requires --prepared and --prior output paths" RESET);
                return EXIT_FAILURE;
            }
            NSError *error = nil;
            BOOL success = prepareSessionCapes([settings objectForKey:@"prepare"], prepared, prior, &error);
            if (!success)
                MMLog(BOLD RED "%s" RESET, error.localizedDescription.UTF8String);
            return success ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (applySession) {
            NSString *expected = [settings objectForKey:@"expect"];
            if (!expected) {
                MMLog(BOLD RED "--apply-session requires --expect prior.cape" RESET);
                return EXIT_FAILURE;
            }
            return applyCapeSessionAtPath([settings objectForKey:@"apply-session"], expected) ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (restoreSession) {
            return restoreCapeSessionAtPath([settings objectForKey:@"restore-session"]) ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (apply) {
            // Apply a cape at a given path
            return applyCapeAtPath([settings objectForKey:@"apply"]) ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (create || convert) {
            NSError *error  = nil;
            NSString *input = create ? [settings objectForKey:@"create"] : [settings objectForKey:@"convert"];
            NSString *output = [settings isKeyPresentAtThisLevel:@"output"] ? [settings objectForKey:@"output"] : input.stringByDeletingLastPathComponent;
            
            error = createCape(input, output, convert);
            if (error) {
                MMLog(BOLD RED "%s" RESET, error.localizedDescription.UTF8String);
            } else {
                MMLog(BOLD GREEN "Cape successfully written to %s" RESET, output.UTF8String);
            }
            goto fin;

        } else if (export) {
            NSString *input = [settings objectForKey:@"export"];
            NSString *output = [settings isKeyPresentAtThisLevel:@"output"] ? [settings objectForKey:@"output"] : nil;
            if (!output) {
                MMLog(BOLD RED "You must specify an output directory with -o!" RESET);
            } else {
                exportCape([NSDictionary dictionaryWithContentsOfFile:input], output);
            }
            goto fin;

        } else if (verify) {
            return verifyCapeAtPath([settings objectForKey:@"verify"]) ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (checkReadback) {
            return checkCursorReadback() ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (probe) {
            probeCursorOverrides();
            goto fin;
        } else if (dumpSafe) {
            NSError *error = nil;
            BOOL success = dumpCursorsSafelyToFile([settings objectForKey:@"dump-safe"], &error);
            if (!success)
                MMLog(BOLD RED "%s" RESET, error.localizedDescription.UTF8String);
            return success ? EXIT_SUCCESS : EXIT_FAILURE;
        } else if (dump) {
            dumpCursorsToFile([settings objectForKey:@"dump"], ^BOOL (NSUInteger progress, NSUInteger total) {
                MMLog("Dumped %lu of %lu", (unsigned long)progress, (unsigned long)total);
                return YES;
            });
        } else if (scale) {
            NSNumber *number = [settings objectForKey:@"scale"];
            
            if (argc == 2) {
                MMLog("%f", cursorScale());
            } else {
                float dbl = number.floatValue;
                setCursorScale(dbl);
            }
            goto fin;
        } else if (listen) {
            listener();
            goto fin;
        }
        fin: {
            if (!suppressCopyright)
                [options replacePlaceholdersAndPrintStringFromBlock:options.printHelpFooter];
        }
        
        return EXIT_SUCCESS;
    }
}
