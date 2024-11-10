//
//  main.m
//  GetRecentWordDocuments
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GetRecentOfficeDocumentsLib.h"

int main(int argc, const char * argv[]) {
    //@autoreleasepool {
    
    NSDictionary* const ICONS = @{@"docx":@"WXBN",@"doc":@"W8BN",@"dotx":@"WXTN",@"dot":@"W8TN",@"docm":@"WXBM",@"dotm":@"WXTM",                                  @"xml":@"WXML",@"mht":@"WDZ9",@"mhtm":@"WDZ9",@"mhtml":@"WDZ9",@"odt":@"ODT"};
    
    NSString* const APP_BUNDLE_ID = @"com.microsoft.Word";
    
    @try {
        // create_LB_menu_entries(APP_BUNDLE_ID, ICONS);
        fprintf(stdout, "%s", create_LB_menu_entries(APP_BUNDLE_ID, ICONS));
        
        return 0;
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
        
        return -1;
    }
    
}
