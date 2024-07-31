//
//  ResultViewController.m
//  FaceDetectorBasedMLKit
//
//  Created by zgy on 2024/7/31.
//

#import "ResultViewController.h"

@interface ResultViewController ()

@end

@implementation ResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIImageView *imgv = [UIImageView new];
    imgv.image = _img;
    imgv.contentMode = UIViewContentModeScaleAspectFill;
    [self.view addSubview:imgv];
    imgv.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [imgv.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [imgv.heightAnchor constraintEqualToAnchor:self.view.heightAnchor],
        [imgv.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [imgv.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    
}

@end
