//
//  ImageDetector.m
//  FaceDetectorBasedMLKit
//
//  Created by zgy on 2024/9/11.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>


//#import <dlib/image_processing.h>
//#import <dlib/image_processing/frontal_face_detector.h>
//#import <dlib/image_processing/render_face_detections.h>
//#import <dlib/opencv.h>
#import <stdio.h>

#import "ImageDetector.h"

#define MIN_IMG_SIZE 480.0
#define MIN_SOBEL_VALUE 2.5
#define MIN_BRIGHTNESS_VALUE 80
#define MAX_BRIGHTNESS_VALUE 200


@implementation ImageDetector
ImageDetector *mImageDetector;

+ (ImageDetector *)shared {
    if(!mImageDetector) {
        mImageDetector = [ImageDetector new];
    }
    return mImageDetector;
}

- (struct ImageQualityResult)checkImageQuality:(UIImage *)img
{
    cv::Mat src;
    UIImageToMat(img, src);
    cv::cvtColor(src, src, cv::COLOR_RGB2BGR);
    struct ImageQualityResult result;
    result.minSize = MIN(src.cols, src.rows);
    if (result.minSize < MIN_IMG_SIZE) {
        result.passed = false;
        return result;
    }
    //若尺寸是符合规定的，再将图片根据长高的比例，保持原图比例缩小较短的一边的长度为 480 像素。
    resizeImg(src);
    cv::Mat gray;
    //转为灰度
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    //检测清晰度
//    result.blur = checkImageQualityBlur(gray);
    result.blur = checkImageQualityBlur2(gray);
    
    //如果小于设定的平均值，则判定为不够清晰。经过实践，该分辨率下，取2.5是比较合理的值。
    if (result.blur < MIN_SOBEL_VALUE) {
        result.passed = false;
        return result;
    }
    result.brightness = checkImageBriteness(src);
    //如果平均亮度在规定范围以外，择判定为过暗或过量。经过实践，范围定在80-200是比较理想的亮度值。
    if (result.brightness < MIN_BRIGHTNESS_VALUE || result.brightness > MAX_BRIGHTNESS_VALUE) {
        result.passed = false;
        return result;
    }
    result.passed = true;
    return result;
}

void resizeImg(cv::Mat &img) {
    int newWidth, newHeight;
    double ratio = img.cols * 1.0 / img.rows * 1.0; //图片长高比
    if (ratio > 1) {
        newHeight = MIN_IMG_SIZE;
        newWidth = MIN_IMG_SIZE * ratio;
    } else {
        newWidth = MIN_IMG_SIZE;
        newHeight = MIN_IMG_SIZE / ratio;
    }
    cv::resize(img, img, cv::Size(newWidth, newHeight));
    cv::cvtColor(img, img, cv::COLOR_RGBA2BGR);
}


double checkImageQualityBlur(cv::Mat &img) {
    cv::Mat sobel;
    // Tenengrad梯度方法利用Sobel算子分别计算水平和垂直方向的梯度，梯度值越高，图像越清晰。
    cv::Sobel(img, sobel, CV_16U, 1, 1);
    // 图像的平均梯度值
    double meanValue = cv::mean(sobel)[0];
    return meanValue;
}

double checkImageQualityBlur2(cv::Mat &img) {
    cv::Mat dst0;
    // 高斯模糊去除噪点
    cv::GaussianBlur(img, dst0, cv::Size(5, 5), 0);
    
    cv::Mat dst1;
    cv::Laplacian(dst0, dst1, CV_64F);
    
    // 将结果转换为正数
    cv::Mat laplacianAbs;
    cv::convertScaleAbs(dst1, laplacianAbs);
    
    double meanValue = cv::mean(laplacianAbs)[0];
    return meanValue;
}


double checkImageBriteness(cv::Mat &img) {
    cv::Mat hsvImg;
    //将图像转换为HSV色彩空间，提取亮度信息。
    cv::cvtColor(img, hsvImg, cv::COLOR_BGR2HSV);
    //计算hsv中的亮度平均值
    double meanValue = cv::mean(hsvImg)[2];
    return meanValue;
}
@end
