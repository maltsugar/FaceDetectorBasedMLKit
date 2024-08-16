//
//  YDFaceErrorView.m
//  DriverApp
//
//  Created by zgy on 2024/8/15.
//  Copyright © 2024 LS-LONG. All rights reserved.
//

#import "YDFaceErrorView.h"

@implementation YDFaceErrorView

+ (instancetype)errorView
{
    NSArray *arr = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self) owner:nil options:nil];
    return [arr lastObject];
}

@end
