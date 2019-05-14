//
//  main.m
//  emporter-cli
//
//  Created by Mikey on 21/04/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <curses.h>
#import <term.h>
#import <stdlib.h>
#import <locale.h>

#import "EMMainCommand.h"

int main(int argc, const char * argv[]) {
    int erret = 0;
    if ((setupterm(NULL, 1, &erret) == ERR) || !has_colors()) {
        YDCommandOutputStyleDisabled = YES;
    }
    
    setlocale(LC_ALL, "en_US.UTF-8");

    int result = 0;
    
    // Run main command in an autoreleasepool for any cleanup depending on dealloc
    @autoreleasepool {
        result = [[EMMainCommand new] run];
    }
    
    return result;
}
