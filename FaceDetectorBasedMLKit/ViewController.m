//
//  ViewController.m
//  FaceDetectorBasedMLKit
//
//  Created by zgy on 2024/7/31.
//

#import "ViewController.h"
#import "FaceViewController.h"
#import "ResultViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (IBAction)startTest {
    
    FaceViewController *facevc = [FaceViewController new];
    [facevc setSuccessBlock:^(UIImage * _Nonnull image) {
        ResultViewController *rvc = [ResultViewController new];
        rvc.img = image;
        [self.navigationController pushViewController:rvc animated:YES];
    }];
    
    [self.navigationController pushViewController:facevc animated:YES];
}


@end
