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
    __weak typeof(self) weakSelf = self;
    
    FaceViewController *facevc = [FaceViewController new];
    facevc.title = @"打卡";
//    facevc.timeoutSeconds = 60;
//    facevc.staySeconds = 2;
    
    [facevc setSuccessBlock:^(UIImage * _Nonnull image) {
        ResultViewController *rvc = [ResultViewController new];
        rvc.img = image;
        [self.navigationController pushViewController:rvc animated:YES];
    }];
    
    __weak typeof(facevc) weakFaceVC = facevc;
    
    [facevc setFailureBlock:^(NSError * _Nonnull error) {
        NSLog(@"%@", error.localizedDescription);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *retry = [UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakFaceVC restart];
        }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];

        [alert addAction:cancel];
        [alert addAction:retry];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    }];
    
    
    [self.navigationController pushViewController:facevc animated:YES];
    
    // or
//    [self addChildViewController:facevc];
//    [self.view addSubview:facevc.view];
}


@end
