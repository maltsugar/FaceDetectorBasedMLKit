//
//  FaceViewController.h
//  TestApp
//
//  Created by zgy on 2024/7/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FaceViewController : UIViewController


@property (nonatomic,   copy) void(^successBlock)(UIImage *image);

@end

NS_ASSUME_NONNULL_END
