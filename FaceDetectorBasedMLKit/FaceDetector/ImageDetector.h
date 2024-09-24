//
//  ImageDetector.h
//  FaceDetectorBasedMLKit
//
//  Created by zgy on 2024/9/11.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface ImageDetector : NSObject


struct ImageQualityResult {
    bool passed;
    double brightness;
    double blur;
    int minSize;
};


+ (ImageDetector *)shared;
- (struct ImageQualityResult)checkImageQuality:(UIImage *)img;

@end




