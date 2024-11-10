//
//  main.m
//  GetRecentPowerPointDocuments
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GetRecentOfficeDocumentsLib.h"

int main(int argc, const char * argv[]) {
    //@autoreleasepool {
    
    NSDictionary* const ICONS = @{@"pptx":@"PPTX", @"xml":@"PPTX", @"thmx":@"THMX", @"ppt":@"SLD8", @"potx":@"POTX", @"pot":@"PPOT", @"odp":@"PODP", @"ppsx":@"PPSX", @"pps":@"PPSS", @"pptm":@"PPTM", @"potm":@"POTM", @"ppsm":@"PPSM"};
    
    NSString* const APP_BUNDLE_ID = @"com.microsoft.Powerpoint";
    
    @try {
        
        fprintf(stdout, "%s", create_LB_menu_entries(APP_BUNDLE_ID, ICONS));
        
        return 0;
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
        
        return -1;
    }
    
}

