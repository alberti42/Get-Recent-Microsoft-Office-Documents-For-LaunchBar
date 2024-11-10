//
//  GetRecentOfficeDocumentsLib.m
//  GetRecentOfficeDocumentsLib
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <string.h>
#include <sys/stat.h>

#import "GetRecentOfficeDocumentsLib.h"

const int BMK_URL_ST_ABSOLUTE = 0x0001;
const int BMK_URL_ST_RELATIVE = 0x0002;

const int BMK_DATA_TYPE_MASK = 0xffffff00;
const int BMK_DATA_SUBTYPE_MASK = 0x000000ff;

const int BMK_STRING  = 0x0100;
const int BMK_DATA    = 0x0200;
const int BMK_NUMBER  = 0x0300;
const int BMK_DATE    = 0x0400;
const int BMK_BOOLEAN = 0x0500;
const int BMK_ARRAY   = 0x0600;
const int BMK_DICT    = 0x0700;
const int BMK_UUID    = 0x0800;
const int BMK_URL     = 0x0900;
const int BMK_NULL    = 0x0a00;

const int BMK_ST_ZERO = 0x0000;
const int BMK_ST_ONE  = 0x0001;

const int BMK_BOOLEAN_ST_FALSE = 0x0000;
const int BMK_BOOLEAN_ST_TRUE  = 0x0001;

NSString* const kOffice2016RecentDocumentsPlist = @"~/Library/Containers/%@/Data/Library/Preferences/%@.securebookmarks.plist";

typedef struct {
    int tocsize;  // Size of TOC in bytes, minus 8
    int tocmagic; // Magic number (0xfffffffe)
    int tocid;    // Identifier (just a number)
    int nexttoc;  // Next TOC offset (or 0 if none)
    int toccount; // Number of entries in this TOC
} str_BookmarkTOCHeader;

typedef struct {
    int eid;
    int eoffset;
    int edummy;
} str_BookmarkTOCEntries;


@interface TocsItem : NSObject
@property (nonatomic, assign) int eid;
@property (nonatomic, retain) NSMutableDictionary* tocs;
@end

@implementation TocsItem

@synthesize eid, tocs;

- (id)initWithTocs:(NSMutableDictionary*)tocs andID:(int)eid{
    self = [super init];
    if( self )
    {
        self.eid = eid;
        self.tocs = tocs;
    }
    return self;
}


- (NSString*)description {
    return [NSString stringWithFormat:@"<%@:%p %@>",
            [self className],
            self,
            @{ @"EID"           : @(self.eid),
               @"tocs"          : self.tocs,
               }];
}

@end

double change_endian(double input)
{
    char* p = (char*)(&input);
    double tmp;
    for (size_t i = 0; i < sizeof(double) / 2; ++i)
    {
        tmp = p[i];
        p[i] = p[sizeof(double) - i - 1];
        p[sizeof(double) - i - 1] = tmp;
    }
    return input;
}

id get_bookmark_item(Byte* data, NSInteger len, int hdrsize, int offset)  __attribute__((ns_returns_retained))
{
    offset += hdrsize;
    if( offset > (len - 8) )
    {
        [[NSException exceptionWithName:@"OffsetOutOfRange" reason:@"Offset out of range" userInfo:nil] raise];
    }
    
    int length =   *((int*)(data + offset + 0x00));
    int typecode = *((int*)(data + offset + 0x04));
    
    if( (len - offset) < (8 + length) )
    {
        [[NSException exceptionWithName:@"DataItemTruncated" reason:@"Data item truncated" userInfo:nil] raise];
    }
    
    Byte* databytes = (Byte*)malloc(length);
    memcpy(databytes, data+offset+8, length);
    
    int dsubtype = typecode & BMK_DATA_SUBTYPE_MASK;
    int dtype = typecode & BMK_DATA_TYPE_MASK;
    
    id ret = nil;
    
    if(dtype == BMK_STRING)
    {
        ret = [[NSString alloc] initWithBytes:databytes length:length encoding:NSUTF8StringEncoding];
        // NSLog(@"String: %@\n",ret);
    }
    else if(dtype == BMK_DATA)
    {
        ret = [[NSData alloc] initWithBytes:databytes length:length];
        // NSLog(@"Data: %@\n",ret);
    }
    else if(dtype == BMK_NUMBER)
    {
        if(dsubtype == kCFNumberSInt8Type)
        {
            unsigned char val = *((unsigned char*)databytes);
            // NSLog(@"Char: %x\n",val);
            ret = @(val);
        }
        else if(dsubtype == kCFNumberSInt16Type)
        {
            short val = *((short*)databytes);
            // NSLog(@"Short: %d\n",val);
            ret = @(val);
        }
        else if(dsubtype == kCFNumberSInt32Type)
        {
            int val = *((int*)databytes);
            // NSLog(@"Int: %d\n",val);
            ret = @(val);
        }
        else if(dsubtype == kCFNumberSInt64Type)
        {
            long int val = *((long int*)databytes);
            // NSLog(@"Long int: %ld\n",val);
            ret = @(val);
        }
        else if(dsubtype == kCFNumberFloat32Type)
        {
            float val = *((float*)databytes);
            // NSLog(@"Float: %f\n",val);
            ret = @(val);
        }
        else if(dsubtype == kCFNumberFloat64Type)
        {
            double val = *((double*)databytes);
            // NSLog(@"Double: %f\n",val);
            ret = @(val);
        }
    }
    else if( dtype == BMK_DATE )
    {
        double date = *((double*)databytes);
        ret = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:change_endian(date)];
        // NSLog(@"Date: %@\n",ret);
    }
    else if( dtype == BMK_BOOLEAN)
    {
        if(dsubtype == BMK_BOOLEAN_ST_TRUE)
        {
            //NSLog(@"Bool: true\n");
            ret = @(true);
        }
        else if(dsubtype == BMK_BOOLEAN_ST_FALSE)
        {
            // NSLog(@"Bool: false\n");
            ret = @(false);
        }
    }
    else if(dtype == BMK_UUID)
    {
        // NSLog(@"UUID\n");
        ret = [[NSUUID alloc] initWithUUIDBytes:databytes];
    }
    else if(dtype == BMK_URL)
    {
        if( dsubtype == BMK_URL_ST_ABSOLUTE )
        {
            ret = [[NSURL alloc] initWithString:[[NSString alloc] initWithBytes:databytes length:length encoding:NSUTF8StringEncoding]];
            
            // NSLog(@"Absolute URL: %@\n",ret);
        }
        else if( dsubtype == BMK_URL_ST_RELATIVE )
        {
            int baseoff = *((int*)(databytes+0x00));
            int reloff  = *((int*)(databytes+0x04));
            
            NSString* base = get_bookmark_item(data, length, hdrsize, baseoff);
            NSString* rel =  get_bookmark_item(data, length, hdrsize, reloff);
            
            // NSLog(@"Relative URL: %@ -- %@\n",base,ret);
            
            ret = [[NSURL alloc] initWithString:rel relativeToURL:[[NSURL alloc] initWithString:base]];
        }
        
        
    }
    else if( dtype == BMK_ARRAY)
    {
        ret = [[NSMutableArray alloc] init];
        
        int eltoff = 0;
        
        for( int aoff = offset+0x08; aoff<(offset+0x08+length); aoff+=0x04)
        {
            eltoff = *((int*)(data+aoff));
            
            [ret addObject:get_bookmark_item(data, len, hdrsize, eltoff)];
        }
        
        // NSLog(@"Binary data: %@",ret);
    }
    else if(dtype == BMK_DICT)
    {
        ret = [[NSMutableDictionary alloc] initWithCapacity:1];
        
        int keyoff = 0;
        int valoff = 0;
        
        for( int eoff = offset+0x08; eoff<(offset+0x08+length); eoff+=0x08)
        {
            keyoff = *((int*)(data+eoff+0x00));
            valoff = *((int*)(data+eoff+0x04));
            
            id key = get_bookmark_item(data, len, hdrsize, keyoff);
            id val = get_bookmark_item(data, len, hdrsize, valoff);
            
            [ret setObject:val forKey:key];
        }
        // NSLog(@"Dictionary: %@",ret);
    }
    else if(dtype == BMK_NULL)
    {
        //NSLog(@"Null");
    }
    
    free(databytes);
    
    return ret;
}

NSMutableArray* parse_bookmark(NSData* d) __attribute__((ns_returns_retained))
{
    NSUInteger len = [d length];
    Byte *byteData = (Byte*)malloc(len);
    memcpy(byteData, [d bytes], len);
    
    if(len<16)
        [[NSException exceptionWithName:@"BookmarkFileTooShort" reason:@"Not a bookmark file (too short)" userInfo:nil] raise];
    
    typedef struct {
        char magic[4];  // "book"
        int size;        // total size
        Byte dummy[4];  // 0x10040000
        int hdrsize;    // header size
        Byte reserved2[32];
        int tocoffset;   // size of toc
    } str_BookmarkHeader;
    
    str_BookmarkHeader* BookmarkHeader;
    
    BookmarkHeader = (str_BookmarkHeader*)(byteData);
    
    // check magic characters
    char* s = (char*)malloc(sizeof(BookmarkHeader->magic)+1);
    memset(s,0,5);
    memcpy(s,BookmarkHeader->magic,sizeof(BookmarkHeader->magic));
    
    // printf("Magic word: %s\n",s);
    
    if( strcmp(s, "book") !=0 )
    {
        [[NSException exceptionWithName:@"BadMagic" reason:[NSString stringWithFormat:@"Not a bookmark file (bad magic): %s", s] userInfo:nil] raise];
    }
    
    free(s);
    
    if(BookmarkHeader->hdrsize < 16)
    {
        [[NSException exceptionWithName:@"TooShortHeader" reason:@"Not a bookmark file (header size too short)" userInfo:nil] raise];
    }
    
    if(BookmarkHeader->hdrsize > BookmarkHeader->size)
    {
        [[NSException exceptionWithName:@"TooLargeHeader" reason:@"Not a bookmark file (header size too large)" userInfo:nil] raise];
    }
    
    if(BookmarkHeader->size != len)
    {
        [[NSException exceptionWithName:@"BookmarkTruncated" reason:@"Not a bookmark file (truncated)" userInfo:nil] raise];
    }
    
    int tocbase;
    
    str_BookmarkTOCHeader* BookmarkTOCHeader = nil;
    
    str_BookmarkTOCEntries* BookmarkTOCEntries = nil;
    
    int n;
    int ebase;
    
    NSMutableArray *tocs = [[NSMutableArray alloc] init];
    
    while(BookmarkHeader->tocoffset != 0)
    {
        tocbase = BookmarkHeader->hdrsize + BookmarkHeader->tocoffset;
        if(BookmarkHeader->tocoffset > (BookmarkHeader->size - BookmarkHeader->hdrsize) ||  (BookmarkHeader->size - tocbase) < 20)
        {
            [[NSException exceptionWithName:@"TOCOutOfRange" reason:@"TOC offset out of range" userInfo:nil] raise];
        }
        
        BookmarkTOCHeader = (str_BookmarkTOCHeader*)(byteData + tocbase);
        
        if(BookmarkTOCHeader->tocmagic != 0xfffffffe)
        {
            break;
        }
        
        BookmarkTOCHeader->tocsize += 8;
        
        if( (BookmarkHeader->size - tocbase) < BookmarkTOCHeader->tocsize)
        {
            [[NSException exceptionWithName:@"TOCtruncated" reason:@"TOC truncated" userInfo:nil] raise];
        }
        
        if( BookmarkTOCHeader->tocsize < 12 * BookmarkTOCHeader->toccount)
        {
            [[NSException exceptionWithName:@"TooManyTOCentries" reason:@"TOC entries overrun TOC size" userInfo:nil] raise];
        }
        
        NSMutableDictionary *toc =  [[NSMutableDictionary alloc] init];
        
        for(n = 0; n<BookmarkTOCHeader->toccount; n++)
        {
            ebase = tocbase + 20 + 12 * n;
            
            BookmarkTOCEntries = (str_BookmarkTOCEntries*)(byteData + ebase);
            
            id result = get_bookmark_item(byteData, len, BookmarkHeader->hdrsize, BookmarkTOCEntries->eoffset);
            
            if((BookmarkTOCEntries->eid & 0x80000000) != 0)
            {
                NSString* customkey = get_bookmark_item(byteData, len, BookmarkHeader->hdrsize, BookmarkTOCEntries->eid & 0x7fffffff);
                // NSLog(@"(HELLLLLLO!!! %@\n",customkey);
                [toc setObject:result forKey:customkey];
            }
            else
            {
                [toc setObject:result forKey:[NSString stringWithFormat: @"0x%04x",BookmarkTOCEntries->eid]];
            }
            
        }
        
        [tocs addObject:@[@(BookmarkTOCHeader->tocid), toc]];
        
        BookmarkHeader->tocoffset = BookmarkTOCHeader->nexttoc;
    }
    
    free(byteData);
    
    return tocs;
}

NSMutableArray* get_recent_documents(NSString* bundleIdentifier) __attribute__((ns_returns_retained))
{
    // ms2016
    NSDictionary *ms2016Dict = [NSDictionary dictionaryWithContentsOfFile:[[NSString stringWithFormat:kOffice2016RecentDocumentsPlist, bundleIdentifier, bundleIdentifier] stringByExpandingTildeInPath]];
    
    NSMutableArray *documentsArray = [[NSMutableArray alloc] initWithCapacity:20];
    
    if (ms2016Dict)
    { // MS Office 2016
        for (NSDictionary *fileDict in [ms2016Dict allValues])
        {
            // NSLog(@"\nReading new bookmark...\n");
            
            NSString* kUUIDKey = [fileDict objectForKey:@"kUUIDKey"];
            
            if(kUUIDKey)
            {
                
                NSData *d = [fileDict objectForKey:@"kBookmarkDataKey"];
                
                // NSDictionary *dd = [NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:d];
                //
                //            if (![dd count]) {
                //                continue;
                //            }
                
                /*
                 NSURL* test2 = [[NSURL alloc] initFileURLWithPath:@"/Users/andrea"];
                 NSURL* test1 = [[NSURL alloc] initFileURLWithPath:@"printenv.andrea" relativeToURL:test2];
                 d = [test1 bookmarkDataWithOptions:NSURLBookmarkCreationSuitableForBookmarkFile includingResourceValuesForKeys:nil
                 relativeToURL:nil error:nil];
                 */
                
                [documentsArray addObject:[parse_bookmark(d) objectAtIndex:0]];
                
                //NSLog(@"\n%@\n",[(NSArray*)[(TocsItem*)tocs[0] tocs][@"0x1004"] componentsJoinedByString:@"/"]);
                
                //            NSString *posixPath = [dd objectForKey:NSURLPathKey];
                //            if ([fm fileExistsAtPath:posixPath]) {
                //                [documentsArray addObject:[(TocsItem*)tocs[0] tocs]];
                //            }
                
                
                //                NSString *posixPath = [(TocsItem)tocs[0] tocs]  objectForKey:NSURLPathKey];
                //                if ([fm fileExistsAtPath:posixPath]) {
                //                    [documentsArray addObject:posixPath];
                //                }
                //                NSLog(@"%@\n",[(TocsItem*)tocs[0] tocs][@"0x1004"]);
                //                NSLog(@"%@\n",tocs[0]);
                
                // break;
                
            }
        }
        
        
    }
    else { // if versions of Microsoft Office other than 2016
        
    }
//    NSLog(@"%@\n",documentsArray);
//    exit(1);
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
        
        for(NSMutableArray* BMKentry in documentsArray)
        {
            
            filepath = [NSString stringWithFormat:@"%@%@",
                           BMKentry[1][@"0x2002"],
                           [BMKentry[1][@"0x1004"] componentsJoinedByString:@"/"]];
            
            //NSLog(@"%@",filepathURL);
            //NSLog(@"%@",[fileURL path]);
            
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
                st_atime1 = filestat1.st_atime;
            }
            if(stat([entry2[@"path"] fileSystemRepresentation], &filestat2)==0)
            {
                st_atime2 = filestat2.st_atime;
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
