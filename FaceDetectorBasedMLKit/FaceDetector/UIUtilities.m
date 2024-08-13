//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "UIUtilities.h"
@import MLKit;



static CGFloat const circleViewAlpha = 0.7;
static CGFloat const rectangleViewAlpha = 0.3;
static CGFloat const shapeViewAlpha = 0.3;
static CGFloat const rectangleViewCornerRadius = 10.0;

static NSString *const MLKCircleViewIdentifier = @"MLKit Circle View";
static NSString *const MLKLineViewIdentifier = @"MLKit Line View";
static NSString *const MLKRectangleViewIdentifier = @"MLKit Rectangle View";

NS_ASSUME_NONNULL_BEGIN

@implementation UIUtilities

+ (void)addCircleAtPoint:(CGPoint)point
                  toView:(UIView *)view
                   color:(UIColor *)color
                  radius:(CGFloat)radius {
  CGFloat divisor = 2.0;
  CGFloat xCoord = point.x - radius / divisor;
  CGFloat yCoord = point.y - radius / divisor;
  CGRect circleRect = CGRectMake(xCoord, yCoord, radius, radius);
  UIView *circleView = [[UIView alloc] initWithFrame:circleRect];
  circleView.layer.cornerRadius = radius / divisor;
  circleView.alpha = circleViewAlpha;
  circleView.backgroundColor = color;
  circleView.isAccessibilityElement = YES;
  circleView.accessibilityIdentifier = MLKCircleViewIdentifier;
  [view addSubview:circleView];
}

+ (void)addLineSegmentFromPoint:(CGPoint)fromPoint
                        toPoint:(CGPoint)toPoint
                         inView:(UIView *)view
                          color:(UIColor *)color
                          width:(CGFloat)width {
  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:fromPoint];
  [path addLineToPoint:toPoint];
  CAShapeLayer *lineLayer = [CAShapeLayer layer];
  lineLayer.path = path.CGPath;
  lineLayer.strokeColor = color.CGColor;
  lineLayer.fillColor = nil;
  lineLayer.opacity = 1.0f;
  lineLayer.lineWidth = width;
  UIView *lineView = [[UIView alloc] initWithFrame:view.bounds];
  [lineView.layer addSublayer:lineLayer];
  [view addSubview:lineView];
}

+ (void)addRectangle:(CGRect)rectangle toView:(UIView *)view color:(UIColor *)color {
  UIView *rectangleView = [[UIView alloc] initWithFrame:rectangle];
  rectangleView.layer.cornerRadius = rectangleViewCornerRadius;
  rectangleView.alpha = rectangleViewAlpha;
  rectangleView.backgroundColor = color;
  rectangleView.isAccessibilityElement = YES;
  rectangleView.accessibilityIdentifier = MLKRectangleViewIdentifier;
  [view addSubview:rectangleView];
}

+ (void)addShapeWithPoints:(NSArray<NSValue *> *)points
                    toView:(UIView *)view
                     color:(UIColor *)color {
  UIBezierPath *path = [UIBezierPath new];
  for (int i = 0; i < [points count]; i++) {
    CGPoint point = points[i].CGPointValue;
    if (i == 0) {
      [path moveToPoint:point];
    } else {
      [path addLineToPoint:point];
    }
    if (i == points.count - 1) {
      [path closePath];
    }
  }
  CAShapeLayer *shapeLayer = [CAShapeLayer new];
  shapeLayer.path = path.CGPath;
  shapeLayer.fillColor = color.CGColor;
  CGRect rect = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
  UIView *shapeView = [[UIView alloc] initWithFrame:rect];
  shapeView.alpha = shapeViewAlpha;
  [shapeView.layer addSublayer:shapeLayer];
  [view addSubview:shapeView];
}

+ (UIImageOrientation)imageOrientation {
  return [self imageOrientationFromDevicePosition:AVCaptureDevicePositionBack];
}

+ (UIImageOrientation)imageOrientationFromDevicePosition:(AVCaptureDevicePosition)devicePosition {
  UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
  if (deviceOrientation == UIDeviceOrientationFaceDown ||
      deviceOrientation == UIDeviceOrientationFaceUp ||
      deviceOrientation == UIDeviceOrientationUnknown) {
    deviceOrientation = [self currentUIOrientation];
  }
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
      return devicePosition == AVCaptureDevicePositionFront ? UIImageOrientationLeftMirrored
                                                            : UIImageOrientationRight;
    case UIDeviceOrientationLandscapeLeft:
      return devicePosition == AVCaptureDevicePositionFront ? UIImageOrientationDownMirrored
                                                            : UIImageOrientationUp;
    case UIDeviceOrientationPortraitUpsideDown:
      return devicePosition == AVCaptureDevicePositionFront ? UIImageOrientationRightMirrored
                                                            : UIImageOrientationLeft;
    case UIDeviceOrientationLandscapeRight:
      return devicePosition == AVCaptureDevicePositionFront ? UIImageOrientationUpMirrored
                                                            : UIImageOrientationDown;
    case UIDeviceOrientationFaceDown:
    case UIDeviceOrientationFaceUp:
    case UIDeviceOrientationUnknown:
      return UIImageOrientationUp;
  }
}

+ (UIDeviceOrientation)currentUIOrientation {
  UIDeviceOrientation (^deviceOrientation)(void) = ^UIDeviceOrientation(void) {
    switch (UIApplication.sharedApplication.statusBarOrientation) {
      case UIInterfaceOrientationLandscapeLeft:
        return UIDeviceOrientationLandscapeRight;
      case UIInterfaceOrientationLandscapeRight:
        return UIDeviceOrientationLandscapeLeft;
      case UIInterfaceOrientationPortraitUpsideDown:
        return UIDeviceOrientationPortraitUpsideDown;
      case UIInterfaceOrientationPortrait:
      case UIInterfaceOrientationUnknown:
        return UIDeviceOrientationPortrait;
    }
  };

  if (NSThread.isMainThread) {
    return deviceOrientation();
  } else {
    __block UIDeviceOrientation currentOrientation = UIDeviceOrientationPortrait;
    dispatch_sync(dispatch_get_main_queue(), ^{
      currentOrientation = deviceOrientation();
    });
    return currentOrientation;
  }
}


+ (UIImage *)UIImageFromImageBuffer:(CVImageBufferRef)imageBuffer
                        orientation:(UIImageOrientation)orientation
{
    return [self UIImageFromImageBuffer:imageBuffer orientation:orientation scale:1.0f];
}

+ (UIImage *)UIImageFromImageBuffer:(CVImageBufferRef)imageBuffer
                        orientation:(UIImageOrientation)orientation scale:(CGFloat)scale
{

  CIImage *CIImg = [CIImage imageWithCVPixelBuffer:imageBuffer];
  CIContext *context = [[CIContext alloc] initWithOptions:nil];
  CGImageRef CGImg = [context createCGImage:CIImg fromRect:CIImg.extent];
  UIImage *image = [UIImage imageWithCGImage:CGImg scale:scale orientation:orientation];
  CGImageRelease(CGImg);
  return image;
}



+ (CVImageBufferRef)imageBufferFromUIImage:(UIImage *)image {
  size_t width = CGImageGetWidth(image.CGImage);
  size_t height = CGImageGetHeight(image.CGImage);

  CVPixelBufferRef imageBuffer;
  CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                      (__bridge CFDictionaryRef) @{}, &imageBuffer);

  CVPixelBufferLockBaseAddress(imageBuffer, 0);

  void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
  CGContextRef context = CGBitmapContextCreate(
      baseAddress, width, height, /*bitsPerComponent=*/8, bytesPerRow, colorSpace,
      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

  CGRect rect = CGRectMake(0, 0, width, height);
  CGContextClearRect(context, rect);
  CGContextDrawImage(context, rect, image.CGImage);

  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

  return imageBuffer;
}

/**
 * Adds a gradient-colored line segment subview in a given `view`.
 *
 * @param fromPoint The starting point of the line, in the view's coordinate space.
 * @param toPoint The end point of the line, in the view's coordinate space.
 * @param view The view to which the line should be added as a subview.
 * @param colors The colors that the gradient should traverse over. Must be non-empty.
 * @param width The width of the line segment.
 */
+ (void)addLineSegmentFromPoint:(CGPoint)fromPoint
                        toPoint:(CGPoint)toPoint
                         inView:(UIView *)view
                         colors:(NSArray<UIColor *> *)colors
                          width:(CGFloat)width {
  CGFloat viewWidth = CGRectGetWidth(view.bounds);
  CGFloat viewHeight = CGRectGetHeight(view.bounds);
  if (viewWidth == 0.0f || viewHeight == 0.0f) {
    return;
  }

  UIBezierPath *path = [UIBezierPath bezierPath];
  [path moveToPoint:fromPoint];
  [path addLineToPoint:toPoint];
  CAShapeLayer *lineMaskLayer = [CAShapeLayer layer];
  lineMaskLayer.path = path.CGPath;
  lineMaskLayer.strokeColor = UIColor.blackColor.CGColor;
  lineMaskLayer.fillColor = nil;
  lineMaskLayer.opacity = 1.0f;
  lineMaskLayer.lineWidth = width;

  CAGradientLayer *gradientLayer = [CAGradientLayer layer];
  gradientLayer.startPoint = CGPointMake(fromPoint.x / viewWidth, fromPoint.y / viewHeight);
  gradientLayer.endPoint = CGPointMake(toPoint.x / viewWidth, toPoint.y / viewHeight);
  gradientLayer.frame = view.bounds;
  NSMutableArray<id> *CGColors = [NSMutableArray arrayWithCapacity:colors.count];
  for (UIColor *color in colors) {
    [CGColors addObject:(id)color.CGColor];
  }
  if (colors.count == 1) {
    // Single-colored lines must still supply a start and end color for the gradient layer to render
    // anything. Just add the single color to the colors list again to fulfill this requirement.
    [CGColors addObject:(id)colors.firstObject.CGColor];
  }
  gradientLayer.colors = CGColors;
  gradientLayer.mask = lineMaskLayer;

  UIView *lineView = [[UIView alloc] initWithFrame:view.bounds];
  [lineView.layer addSublayer:gradientLayer];
  lineView.isAccessibilityElement = YES;
  lineView.accessibilityIdentifier = MLKLineViewIdentifier;
  [view addSubview:lineView];
}

/**
 * Returns a color interpolated between two other colors.
 *
 * @param fromColor The start color of the interpolation.
 * @param toColor The end color of the interpolation.
 * @param ratio The ratio in range [0, 1] by which the colors should be interpolated. Passing 0
 *     results in `fromColor` and passing 1 results in `toColor`, whereas passing 0.5 results in a
 *     color that is half-way between `fromColor` and `startColor`. Values are clamped between 0 and
 *     1.
 */
+ (UIColor *)colorInterpolatedFromColor:(UIColor *)fromColor
                                toColor:(UIColor *)toColor
                                  ratio:(CGFloat)ratio {
  CGFloat fromR, fromG, fromB, fromA;
  [fromColor getRed:&fromR green:&fromG blue:&fromB alpha:&fromA];

  CGFloat toR, toG, toB, toA;
  [toColor getRed:&toR green:&toG blue:&toB alpha:&toA];

  // Clamp ratio to [0, 1]
  ratio = MAX(0.0, MIN(ratio, 1.0));

  CGFloat interpolatedR = fromR + (toR - fromR) * ratio;
  CGFloat interpolatedG = fromG + (toG - fromG) * ratio;
  CGFloat interpolatedB = fromB + (toB - fromB) * ratio;
  CGFloat interpolatedA = fromA + (toA - fromA) * ratio;

  return [UIColor colorWithRed:interpolatedR
                         green:interpolatedG
                          blue:interpolatedB
                         alpha:interpolatedA];
}

/**
 * Returns the distance between two 3D points.
 *
 * @param fromPoint The start point.
 * @param toPoint The end point.
 */
+ (CGFloat)distanceFromPoint:(MLKVision3DPoint *)fromPoint toPoint:(MLKVision3DPoint *)toPoint {
  CGFloat xDiff = fromPoint.x - toPoint.x;
  CGFloat yDiff = fromPoint.y - toPoint.y;
  CGFloat zDiff = fromPoint.z - toPoint.z;
  return sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff);
}

@end

NS_ASSUME_NONNULL_END
