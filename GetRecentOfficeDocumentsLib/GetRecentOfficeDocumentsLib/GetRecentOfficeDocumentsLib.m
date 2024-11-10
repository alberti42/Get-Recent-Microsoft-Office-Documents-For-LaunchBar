//
//  GetRecentOfficeDocumentsLib.m
//  GetRecentOfficeDocumentsLib
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import "GetRecentOfficeDocumentsLib.h"

#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include "BDAlias.h"

NSString* const kOffice2016RecentDocumentsPlist = @"~/Library/Containers/%@/Data/Library/Preferences/%@.securebookmarks.plist";

NSMutableArray* get_recent_documents(NSString* bundleIdentifier) __attribute__((ns_returns_retained))
{
    // ms2016
    NSDictionary *ms2016Dict = [NSDictionary dictionaryWithContentsOfFile:[[NSString stringWithFormat:kOffice2016RecentDocumentsPlist, bundleIdentifier, bundleIdentifier] stringByExpandingTildeInPath]];
    
    NSMutableArray *documentsArray = [[NSMutableArray alloc] initWithCapacity:20];
    
    if (ms2016Dict)
    {
        NSArray* files = [[NSArray alloc] initWithArray:[ms2016Dict allValues]];
        
        NSDictionary* fileDict;
        BDAlias *alias;
        char* s = (char*)malloc(5);
        NSData* d;
        NSDictionary* dd;
        NSString* path;
        NSString* kUUIDKey;
        
        NSEnumerator *enumerator = [files objectEnumerator];
        
        int counter=0;
        
        while ((fileDict = [enumerator nextObject]) && counter < 50) {
            
            kUUIDKey = [fileDict objectForKey:@"kUUIDKey"];
            
            if(kUUIDKey)
            {
                d = [fileDict objectForKey:@"kBookmarkDataKey"];
                
                if( d && [d length] > 4)
                {
                    // check magic characters
                    memset(s,0,5);
                    memcpy(s,[d bytes],4);
                    
                    if( strcmp(s, "book") ==0 ) // a bookmark
                    {
                        dd = [NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:d];
                        
                        if ([dd count] == 0)
                        {
                            continue;
                        }
                        
                        path = dd[NSURLPathKey];
                    }
                    else // an alias of old type
                    {
                        alias = [[BDAlias alloc] initWithData:d];
                        
                        if( alias )
                        {
                            path = [alias fullPath];
                            
                            if( path == nil )
                            {
                                continue;
                            }
                        }
                    }
                    
                    if( access([path fileSystemRepresentation], F_OK ) == -1 )
                    {
                        continue;
                    }
                    
                    [documentsArray addObject:path];
                    counter++;
                }
            }
        }
        free(s);
        
    }
    return documentsArray;
}

const char* create_LB_menu_entries(NSString* const APP_BUNDLE_ID, NSDictionary* const ICONS)
{
    NSMutableArray* documentsArray = get_recent_documents(APP_BUNDLE_ID);

    // NSFileManager *fm = [NSFileManager defaultManager];
    if ([documentsArray count] > 0)
    {
        /*
        [documentsArray sortUsingComparator:^NSComparisonResult(NSArray *entry1, NSArray *entry2) {
            
            
            return [(NSDate*)(entry1[1][@"0x1040"]) compare:(NSDate*)(entry2[1][@"0x1040"])]==NSOrderedAscending;
        }];
         */

        
        /*
         for(NSMutableArray* entry in documentsArray)
         {
         fprintf(stdout,"Filename: %s\n",[[entry[1][@"0x1004"] componentsJoinedByString:@"/"] UTF8String]);
         }
         */
        
        NSArray* LBkeys = @[@"title", @"subtitle", @"path", @"icon"];
        
        NSMutableArray* LBitems = [[NSMutableArray alloc] init];
        
        NSString* filepath;
        NSString* ext;
        NSString* title;
        NSString* subtitle;
        NSString* icon;
        //NSMutableCharacterSet* allowedChars = [NSMutableCharacterSet characterSetWithCharactersInString:@":/"];
        //[allowedChars formUnionWithCharacterSet:[NSCharacterSet URLPathAllowedCharacterSet]];
        
        for(filepath in documentsArray)
        {
            // if( [fm fileExistsAtPath:filepath] )
            if( access( [filepath fileSystemRepresentation], F_OK ) != -1 )
            {
                ext = [filepath pathExtension];
                subtitle = [filepath stringByDeletingLastPathComponent];
                title = [filepath lastPathComponent];
                icon = ICONS[ext];
                if( !icon )
                {
                    icon = @"TEXT";
                }
                
                /*
                int fd = open([filepath fileSystemRepresentation], O_RDONLY);
                if(fstat(fd,&buf)==0)
                {
                    printf("Time: %ld\n",buf.st_atime);
                }
                close(fd);
                */
               
                
               // stat([filepath UTF8String], &filestat1);
                // error handling omitted for this example
//                accessTime = &filestat1.st_atime;
                
                [LBitems addObject:[[NSDictionary alloc] initWithObjects:
                                    @[title,
                                      subtitle,
                                      //[NSString stringWithFormat:@"%@%@",APP_URL_PREFIX,[filepathURL  stringByAddingPercentEncodingWithAllowedCharacters:allowedChars]],
                                      filepath,
                                      [NSString stringWithFormat:@"%@:%@",APP_BUNDLE_ID,[icon lowercaseString]]] forKeys:LBkeys]];
            }
        }
        
        
        [LBitems sortUsingComparator:^NSComparisonResult(NSDictionary *entry1, NSDictionary *entry2) {
            
            long int st_atime1 = 0;
            long int st_atime2 = 0;
            struct stat filestat1;
            struct stat filestat2;
            
            // printf("%s\n",[entry1[@"path"] fileSystemRepresentation]);
            
            if(stat([entry1[@"path"] fileSystemRepresentation], &filestat1)==0)
            {
                st_atime1 = filestat1.st_ctime;
            }
            if(stat([entry2[@"path"] fileSystemRepresentation], &filestat2)==0)
            {
                st_atime2 = filestat2.st_ctime;
            }
            
            return st_atime1<st_atime2;
        }];
        
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:LBitems
                                                           options:NSJSONWritingPrettyPrinted error:nil];
        
        
        //            NSLog(@"%@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
        //            fprintf(stdout,"%s",[[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]);
        
        
        return [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] UTF8String];
    }
    else
    {
        return "";
    }
    
    
    
}
