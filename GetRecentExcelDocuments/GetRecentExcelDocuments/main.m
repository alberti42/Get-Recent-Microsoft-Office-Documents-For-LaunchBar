//
//  main.m
//  GetRecentExcelDocuments
//
//  Created by Andrea Alberti on 18.02.18.
//  Copyright © 2018 Andrea Alberti. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GetRecentOfficeDocumentsLib.h"

int main(int argc, const char * argv[]) {
    //@autoreleasepool {
    
    NSDictionary* const ICONS = @{@"slk":@"XLS8", @"dif":@"XLS8", @"ods":@"ODS", @"xls":@"XLS8", @"xlsx":@"XLSX", @"xltx":@"XLTX", @"xlsm":@"XLSM", @"xltm":@"XLTM", @"xlsb":@"XLSB", @"xlam":@"XLAM", @"xlw":@"XLW8", @"xla":@"XLA8", @"xlb":@"XLB8", @"xlt":@"XLT",@"xld":@"XLD5", @"xlm":@"XLM4", @"xll":@"XLL", @"csv":@"CSV", @"txt":@"TEXT", @"xml":@"XMLS", @"tlb":@"OTLB"};
    
    NSString* const APP_BUNDLE_ID = @"com.microsoft.Excel";
    
    @try {
        
        fprintf(stdout, "%s", create_LB_menu_entries(APP_BUNDLE_ID, ICONS));
        
        return 0;
    }
    @catch (NSException *exception) {
        NSLog(@"%@",exception);
        
        return -1;
    }
    
}

