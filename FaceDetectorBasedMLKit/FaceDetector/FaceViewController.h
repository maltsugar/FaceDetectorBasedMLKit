//
//  FaceViewController.h
//  TestApp
//
//  Created by zgy on 2024/7/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FaceViewController : UIViewController


@property (nonatomic, assign) NSUInteger staySeconds; // 居中保持时间，至少保持这个时间，才算识别成功, default 2s
@property (nonatomic, assign) NSUInteger timeoutSeconds; // 超时时间, default 60s
@property (nonatomic, strong) UIButton *closeBtn;

@property (nonatomic,   copy) void(^successBlock)(UIImage *image);
@property (nonatomic,   copy) void(^failureBlock)(NSError *error);

- (void)restart;


- (void)exit;

@end

NS_ASSUME_NONNULL_END
