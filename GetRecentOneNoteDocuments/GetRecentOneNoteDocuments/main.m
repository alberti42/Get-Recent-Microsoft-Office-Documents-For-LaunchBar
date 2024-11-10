//
//  main.m
//  GetRecentOneNoteDocuments
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GetRecentOfficeDocumentsLib.h"

int main(int argc, const char * argv[]) {
    //@autoreleasepool {
    
    NSDictionary* const ICONS = @{};
    
    NSString* const APP_BUNDLE_ID = @"com.microsoft.onenote.mac";
    
    @try {
        
        fprintf(stdout, "%s", create_LB_menu_entries(APP_BUNDLE_ID, ICONS));
        
        return 0;
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
        
        return -1;
    }
    
}


