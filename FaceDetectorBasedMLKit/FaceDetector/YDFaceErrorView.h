//
//  YDFaceErrorView.h
//  DriverApp
//
//  Created by zgy on 2024/8/15.
//  Copyright © 2024 LS-LONG. All rights reserved.
//

#import <UIKit/UIKit.h>



@interface YDFaceErrorView : UIView

@property (weak, nonatomic) IBOutlet UILabel *tipLab;

@property (weak, nonatomic) IBOutlet UIButton *retryBtn;



+ (instancetype)errorView;

@end

