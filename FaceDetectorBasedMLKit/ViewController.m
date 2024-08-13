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


@property (nonatomic, strong) FaceViewController *facevc;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}
- (IBAction)startTest {
    __weak typeof(self) weakSelf = self;
    
    FaceViewController *facevc = [FaceViewController new];
    _facevc = facevc;
    facevc.title = @"打卡";
//    facevc.timeoutSeconds = 5;
//    facevc.staySeconds = 10;
    
    [facevc setSuccessBlock:^(UIImage * _Nonnull image) {
        ResultViewController *rvc = [ResultViewController new];
        rvc.img = image;
        [self.navigationController pushViewController:rvc animated:YES];
    }];
    
    [facevc setFailureBlock:^(NSError * _Nonnull error) {
        NSLog(@"%@", error.localizedDescription);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *retry = [UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.facevc restart];
        }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];

        [alert addAction:cancel];
        [alert addAction:retry];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    }];
    
    
    [self.navigationController pushViewController:facevc animated:YES];
    
    // or
//    [self.view addSubview:facevc.view];
}


@end
