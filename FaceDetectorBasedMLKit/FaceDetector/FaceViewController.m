//
//  FaceViewController.m
//  TestApp
//
//  Created by zgy on 2024/7/26.
//

#import "FaceViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import "UIUtilities.h"
#import "MaskView.h"
#import "YDFaceErrorView.h"

@import MLImage;
@import MLKit;



static NSString *const videoDataOutputQueueLabel =
@"sjgj.google.mlkit.visiondetector.VideoDataOutputQueue";
static NSString *const sessionQueueLabel = @"sjgj.google.mlkit.visiondetector.SessionQueue";
static const CGFloat MLKSmallDotRadius = 4.0;



@interface FaceViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>


@property (nonatomic, strong) UIView *cameraView;

@property(nonatomic) bool isUsingFrontCamera;
@property(nonatomic, nonnull) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic) AVCaptureSession *captureSession;
@property(nonatomic) dispatch_queue_t sessionQueue;

@property(nonatomic) UIView *annotationOverlayView; // 面部检测 覆盖的view 特征点view
@property(nonatomic) UIImageView *previewOverlayView; // 摄像头输出的 图像帧

@property(nonatomic) CMSampleBufferRef lastFrame;

@property (nonatomic, strong) MaskView *maskView;

@property (nonatomic, assign) CGFloat originBrightness;
@property (nonatomic, strong) dispatch_source_t stayTimer;// 保持不动timer

@property (nonatomic, strong) dispatch_source_t timeoutTimer; // 超时timer

@property (nonatomic, strong) YDFaceErrorView *errorView;

@end

#define kFDScreenW  [UIScreen mainScreen].bounds.size.width
#define kFDScreenH  [UIScreen mainScreen].bounds.size.height


@implementation FaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    if (!_staySeconds) {
        _staySeconds = 2;
    }
    if (!_timeoutSeconds) {
        _timeoutSeconds = 60;
    }
    
    _originBrightness = [[UIScreen mainScreen] brightness];
    [[UIScreen mainScreen] setWantsSoftwareDimming:YES];
   
    _isUsingFrontCamera = YES;

    _cameraView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_cameraView];
    
    
    _captureSession = [[AVCaptureSession alloc] init];
    _sessionQueue = dispatch_queue_create(sessionQueueLabel.UTF8String, nil);
    _previewOverlayView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _previewOverlayView.contentMode = UIViewContentModeScaleAspectFill;
//    _previewOverlayView.contentMode = UIViewContentModeScaleAspectFit;
    _previewOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    
    _annotationOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
    _annotationOverlayView.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    
    _maskView = [MaskView maskView];
    [self.view addSubview:_maskView];
    _maskView.frame = self.view.bounds;
    
    [self setUpPreviewOverlayView];
    [self setUpAnnotationOverlayView];
    [self setUpCaptureSessionOutput];
    [self setUpCaptureSessionInput];
    
    // 错误提示view
    _errorView = [YDFaceErrorView errorView];
    [self.view addSubview:_errorView];
    _errorView.frame = self.view.bounds;
    [_errorView.retryBtn addTarget:self action:@selector(retryBtnAction) forControlEvents:UIControlEventTouchUpInside];
    _errorView.hidden = YES;
    
    // 关闭按钮
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [btn setImage:[UIImage imageNamed:@"close_btn"] forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor.blackColor colorWithAlphaComponent:0.1]];
    [btn setTitle:@"X" forState:UIControlStateNormal];
    btn.layer.cornerRadius = 15;
    btn.clipsToBounds = YES;
    [self.view addSubview:btn];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:30],
        [btn.heightAnchor constraintEqualToConstant:30],
        [btn.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:80],
        [btn.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    ]];
    [btn addTarget:self action:@selector(handleCloseAction) forControlEvents:UIControlEventTouchUpInside];
    _closeBtn = btn;
    

    [self checkCamera];
    
    [self addNotifiObserver];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    _previewLayer.frame = _cameraView.frame;
    
}

- (void)handleCloseAction
{
    // 判断当前控制器是被present出来的还是push出来的
    if (self.presentingViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)retryBtnAction
{
    _errorView.tipLab.text = nil;
    _errorView.hidden = YES;
    
    [self restart];
}

- (void)restart
{
    [self startSession];
}

- (void)exit
{
    [self handleCloseAction];
}

- (void)addNotifiObserver
{
//    // 程序重新进入前台的时候
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startScreenHighlight) name:UIApplicationDidBecomeActiveNotification object:nil];
    // 程序后台挂起
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetScreen) name:UIApplicationWillResignActiveNotification object:nil];
    // 程序退出的时候
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetScreen) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)removeNotiObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - On-Device Detections
- (void)detectFacesOnDeviceInImage:(MLKVisionImage *)image
                             width:(CGFloat)width
                            height:(CGFloat)height {
    // When performing latency tests to determine ideal detection settings, run the app in 'release'
    // mode to get accurate performance metrics.
    MLKFaceDetectorOptions *options = [[MLKFaceDetectorOptions alloc] init];
    options.performanceMode = MLKFaceDetectorPerformanceModeFast;
    options.contourMode = MLKFaceDetectorContourModeAll;
    options.landmarkMode = MLKFaceDetectorLandmarkModeAll;
    options.classificationMode = MLKFaceDetectorClassificationModeNone;
    options.minFaceSize = 0.3;
    
    
    
    MLKFaceDetector *faceDetector = [MLKFaceDetector faceDetectorWithOptions:options];
    NSError *error;
    NSArray<MLKFace *> *faces = [faceDetector resultsInImage:image error:&error];
    __weak typeof(self) weakSelf = self;
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        
        [strongSelf updatePreviewOverlayViewWithLastFrame];
        
        
        [strongSelf removeDetectionAnnotations];
        
       
        if (error != nil) {
            NSLog(@"Failed to detect faces with error: %@", error.localizedDescription);
            return;
        }
        if (faces.count == 0) {
            //            NSLog(@"On-Device face detector returned no results.");
            [strongSelf checkFaceStatus:nil rect:CGRectZero faceCount:0];
            return;
        }
        
        if (faces.count > 1) {
            [strongSelf checkFaceStatus:nil rect:CGRectZero faceCount:(int)faces.count];
            return;
        }
        
        
        for (MLKFace *face in faces) {
            CGRect normalizedRect =
            CGRectMake(face.frame.origin.x / width, face.frame.origin.y / height,
                       face.frame.size.width / width, face.frame.size.height / height);
            
            CGRect rect1 = [strongSelf.previewLayer rectForMetadataOutputRectOfInterest:normalizedRect];
            //            CGRect standardizedRect = CGRectStandardize(rect1);
            CGRect standardizedRect = rect1;
            
            // 检查人脸状态
            [strongSelf checkFaceStatus:face rect:standardizedRect faceCount:1];
            
//            [UIUtilities addRectangle:standardizedRect
//                               toView:strongSelf.annotationOverlayView
//                                color:UIColor.greenColor];
//            [strongSelf addContoursForFace:face width:width height:height];
        }
    });
}

- (void)checkFaceStatus:(MLKFace *)face rect:(CGRect)standardizedRect faceCount:(int)cnt
{
    BOOL isValid = NO;
    NSString *tip = @"";
    if (!face) {
        tip = @"请面向屏幕";
        if (cnt > 1) {
            tip = @"检测到多张人脸";
        }
        
        [self.maskView updateTip:tip isValid:isValid];
        [self checkResult:isValid];
        return;
    }
    

//    NSLog(@"headEulerAngleX: %f", face.headEulerAngleX); // 低头仰头角度 [-6, +6]效果好
//    NSLog(@"headEulerAngleY: %f", face.headEulerAngleY); // 左右摇头角度 [-5, +5]效果好
//    NSLog(@"headEulerAngleZ: %f", face.headEulerAngleZ); // 手机屏幕旋转角度（即脸平面和手机屏幕屏幕平面的交叉角度）[-3, +3]效果好
    
    if (abs((int)face.headEulerAngleX) > 6 ||
        abs((int)face.headEulerAngleY) > 5 ||
        abs((int)face.headEulerAngleZ) > 3
        )
    {
        tip = @"请将保持正脸在框内";
        [self.maskView updateTip: tip isValid:isValid];
        [self checkResult:isValid];
        return;
    }
    
    
    CGFloat centerX = CGRectGetMinX(standardizedRect) + 0.5*CGRectGetWidth(standardizedRect);
    CGFloat centerY = CGRectGetMinY(standardizedRect) + 0.5*CGRectGetHeight(standardizedRect);
    
//    NSLog(@"centerY: %f", centerY);
    
    CGFloat sw = CGRectGetWidth(UIScreen.mainScreen.bounds);
    CGFloat sh = CGRectGetHeight(UIScreen.mainScreen.bounds);
    CGFloat r0 = 0.70;
    CGFloat r1 = 0.35;
    
    if (CGRectGetWidth(standardizedRect) > r0 * sw  || CGRectGetHeight(standardizedRect) > r0 * sh) {
        // 距离过近
        tip = @"请离远一点";
    }else if (CGRectGetWidth(standardizedRect) < r1 * sw  || CGRectGetHeight(standardizedRect) < r1 * sh) {
        // 距离过远
        tip = @"请靠近一点";
    }else {
        // 距离合适  判断是否居中
        if (centerX > 0.4*sw && centerX < 0.6*sw &&
            centerY > 0.5*sh && centerY < 0.6*sh) {
            tip = @"请保持静止不动";
            isValid = YES;
        }else {
//            tip = @"请保持人脸居中";
            tip = @"请将保持正脸在框内";
        }
    }
    
    [self.maskView updateTip: tip isValid:isValid];
    [self checkResult:isValid];
}



- (void)checkResult:(BOOL)isvalid
{
    if (isvalid) {
        // 符合条件 取消超时timer
        [self cancelTimeoutTimer];
        
        
        // 开启计时器2s 后，回调
        __weak typeof(self) weakSelf = self;
        if (!self.stayTimer) {
            __block int seconds = 0;
            self.stayTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
            if (self.stayTimer) {
                dispatch_source_set_timer(self.stayTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 1 * NSEC_PER_SEC, 0);
                dispatch_source_set_event_handler(self.stayTimer, ^{
                    // 定时器触发时执行的任务
                    seconds++;
//                    NSLog(@"seconds: %d", seconds);
                    if (seconds == weakSelf.staySeconds) {
                        [weakSelf stopSession];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (weakSelf.successBlock) {
                                weakSelf.successBlock(weakSelf.previewOverlayView.image);
                            }

                            [weakSelf resetScreen];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                [weakSelf cancelStayTimer];
                                [weakSelf cancelTimeoutTimer];
                            });
                        });
                    }
                    
                });
                dispatch_resume(self.stayTimer);
            }
           
        }
        
    }else
    {
        // 动了  取消计时
        [self cancelStayTimer];
        
        // 不满足检测姿势要求 开启超时timer
        [self startTimeoutTimer];
    }
}




#pragma mark- timer

- (void)cancelStayTimer
{
    if (self.stayTimer) {
        dispatch_source_cancel(self.stayTimer);
        self.stayTimer = nil;
    }
}

- (void)cancelTimeoutTimer
{
    if (self.timeoutTimer) {
        dispatch_source_cancel(self.timeoutTimer);
        self.timeoutTimer = nil;
    }
}

- (void)startTimeoutTimer
{
    __weak typeof(self) weakSelf = self;
    if (!self.timeoutTimer) {
        __block int seconds = 0;
        self.timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        if (self.timeoutTimer) {
            dispatch_source_set_timer(self.timeoutTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 1 * NSEC_PER_SEC, 0);
            dispatch_source_set_event_handler(self.timeoutTimer, ^{
                // 定时器触发时执行的任务
                seconds++;
//                NSLog(@"timeout seconds: %d", seconds);
                if (seconds == weakSelf.timeoutSeconds) {
                    [weakSelf stopSession];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (weakSelf.failureBlock) {
                            NSError *err = [NSError errorWithDomain:@"facedector.sjgy" code:100 userInfo:@{NSLocalizedDescriptionKey: @"检测超时"}];
                            weakSelf.failureBlock(err);
                        }
                        
                        weakSelf.errorView.hidden = NO;
                        weakSelf.errorView.tipLab.text = @"已超时，请重试！";
                        [weakSelf resetScreen];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [weakSelf cancelTimeoutTimer];
                        });
                    });
                }
                
            });
            dispatch_resume(self.timeoutTimer);
        }
    }
      
}

#pragma mark- AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (imageBuffer) {
        // Evaluate `self.currentDetector` once to ensure consistency throughout this method since it
        // can be concurrently modified from the main thread.

        [self checkBrightness:sampleBuffer];
        
        _lastFrame = sampleBuffer;
        MLKVisionImage *visionImage = [[MLKVisionImage alloc] initWithBuffer:sampleBuffer];
        UIImageOrientation orientation = [UIUtilities
                                          imageOrientationFromDevicePosition:_isUsingFrontCamera ? AVCaptureDevicePositionFront
                                          : AVCaptureDevicePositionBack];
        visionImage.orientation = orientation;
        CGFloat imageWidth = CVPixelBufferGetWidth(imageBuffer);
        CGFloat imageHeight = CVPixelBufferGetHeight(imageBuffer);
        [self detectFacesOnDeviceInImage:visionImage width:imageWidth height:imageHeight];
        
    } else {
        NSLog(@"%@", @"Failed to get image buffer from sample buffer.");
    }
}

/// 检测亮度
- (void)checkBrightness:(CMSampleBufferRef)sampleBuffer
{
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary: (__bridge NSDictionary *)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
//        NSLog(@"%f",brightnessValue);
    if (brightnessValue < 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIScreen mainScreen] setBrightness:1];
        });
    }
}


- (void)removeDetectionAnnotations {
    for (UIView *annotationView in _annotationOverlayView.subviews) {
        [annotationView removeFromSuperview];
    }
}

- (void)updatePreviewOverlayViewWithLastFrame {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(_lastFrame);
    [self updatePreviewOverlayViewWithImageBuffer:imageBuffer];
}

- (void)updatePreviewOverlayViewWithImageBuffer:(CVImageBufferRef)imageBuffer {
    if (imageBuffer == nil) {
        return;
    }
    UIImageOrientation orientation =
    _isUsingFrontCamera ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
    UIImage *image = [UIUtilities UIImageFromImageBuffer:imageBuffer orientation:orientation scale:2.0f];
    _previewOverlayView.image = image;
}

#pragma mark - Private
- (void)setUpCaptureSessionOutput {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            NSLog(@"Failed to setUpCaptureSessionOutput because self was deallocated");
            return;
        }
        [strongSelf.captureSession beginConfiguration];
        // When performing latency tests to determine ideal capture settings,
        // run the app in 'release' mode to get accurate performance metrics
        strongSelf.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        
        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        output.videoSettings = @{
            (id)
            kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
        };
        output.alwaysDiscardsLateVideoFrames = YES;
        dispatch_queue_t outputQueue = dispatch_queue_create(videoDataOutputQueueLabel.UTF8String, nil);
        [output setSampleBufferDelegate:self queue:outputQueue];
        if ([strongSelf.captureSession canAddOutput:output]) {
            [strongSelf.captureSession addOutput:output];
            [strongSelf.captureSession commitConfiguration];
        } else {
            NSLog(@"%@", @"Failed to add capture session output.");
        }
    });
}

- (void)setUpCaptureSessionInput {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) {
            NSLog(@"Failed to setUpCaptureSessionInput because self was deallocated");
            return;
        }
        AVCaptureDevicePosition cameraPosition =
        strongSelf.isUsingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        AVCaptureDevice *device = [strongSelf captureDeviceForPosition:cameraPosition];
        if (device) {
            [strongSelf.captureSession beginConfiguration];
            NSArray<AVCaptureInput *> *currentInputs = strongSelf.captureSession.inputs;
            for (AVCaptureInput *input in currentInputs) {
                [strongSelf.captureSession removeInput:input];
            }
            NSError *error;
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                                error:&error];
            if (error) {
                NSLog(@"Failed to create capture device input: %@", error.localizedDescription);
                return;
            } else {
                if ([strongSelf.captureSession canAddInput:input]) {
                    [strongSelf.captureSession addInput:input];
                } else {
                    NSLog(@"%@", @"Failed to add capture session input.");
                }
            }
            [strongSelf.captureSession commitConfiguration];
        } else {
            NSLog(@"Failed to get capture device for camera position: %ld", cameraPosition);
        }
    });
}

- (void)checkCamera
{

//    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
//    switch (authStatus) {
//        case AVAuthorizationStatusNotDetermined:
//            //没有询问
//            
//            break;
//        case AVAuthorizationStatusRestricted:
//            //未授权，家长限制
//            
//            break;
//        case AVAuthorizationStatusDenied:
//            //用户拒绝
//            
//            break;
//        case AVAuthorizationStatusAuthorized:
//            //用户同意
//
//            break;
//        default:
//            break;
//    }
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"进行人脸识别需要授权相机权限，是否去设置打开相机权限？" preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
                UIAlertAction *gotoSetting = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                }];
                
                [alert addAction:cancel];
                [alert addAction:gotoSetting];
                
                [self presentViewController:alert animated:YES completion:nil];
                
                return;
            }
            
            [self startSession];
        });
    }];
}


- (void)startSession {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        [weakSelf.captureSession startRunning];
    });
}

- (void)stopSession {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        [weakSelf.captureSession stopRunning];
    });
}

- (void)setUpPreviewOverlayView {
//    [_cameraView addSubview:_previewOverlayView];
//    [NSLayoutConstraint activateConstraints:@[
//        [_previewOverlayView.centerYAnchor constraintEqualToAnchor:_cameraView.centerYAnchor],
//        [_previewOverlayView.centerXAnchor constraintEqualToAnchor:_cameraView.centerXAnchor],
//        [_previewOverlayView.leadingAnchor constraintEqualToAnchor:_cameraView.leadingAnchor],
//        [_previewOverlayView.trailingAnchor constraintEqualToAnchor:_cameraView.trailingAnchor]
//    ]];
    
    
  
    [_maskView.previewView  addSubview:_previewOverlayView];
    [NSLayoutConstraint activateConstraints:@[
        [_previewOverlayView.centerYAnchor constraintEqualToAnchor:_maskView.previewView.centerYAnchor],
        [_previewOverlayView.centerXAnchor constraintEqualToAnchor:_maskView.previewView.centerXAnchor],
        [_previewOverlayView.leadingAnchor constraintEqualToAnchor:_maskView.previewView.leadingAnchor],
        [_previewOverlayView.trailingAnchor constraintEqualToAnchor:_maskView.previewView.trailingAnchor]
    ]];
    
    
}
- (void)setUpAnnotationOverlayView {
    [_cameraView addSubview:_annotationOverlayView];
    [NSLayoutConstraint activateConstraints:@[
        [_annotationOverlayView.topAnchor constraintEqualToAnchor:_cameraView.topAnchor],
        [_annotationOverlayView.leadingAnchor constraintEqualToAnchor:_cameraView.leadingAnchor],
        [_annotationOverlayView.trailingAnchor constraintEqualToAnchor:_cameraView.trailingAnchor],
        [_annotationOverlayView.bottomAnchor constraintEqualToAnchor:_cameraView.bottomAnchor]
    ]];
}


- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)position {
    if (@available(iOS 10, *)) {
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                             discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ]
                                                             mediaType:AVMediaTypeVideo
                                                             position:AVCaptureDevicePositionUnspecified];
        for (AVCaptureDevice *device in discoverySession.devices) {
            if (device.position == position) {
                return device;
            }
        }
    }
    return nil;
}


#pragma mark- 画脸部特征点
- (CGPoint)normalizedPointFromVisionPoint:(MLKVisionPoint *)point
                                    width:(CGFloat)width
                                   height:(CGFloat)height {
    CGPoint cgPointValue = CGPointMake(point.x, point.y);
    CGPoint normalizedPoint = CGPointMake(cgPointValue.x / width, cgPointValue.y / height);
    CGPoint cgPoint = [_previewLayer pointForCaptureDevicePointOfInterest:normalizedPoint];
    return cgPoint;
}
- (void)addContoursForFace:(MLKFace *)face width:(CGFloat)width height:(CGFloat)height {
    // Face
    MLKFaceContour *faceContour = [face contourOfType:MLKFaceContourTypeFace];
    for (MLKVisionPoint *point in faceContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.blueColor
                               radius:MLKSmallDotRadius];
    }
    
    // Eyebrows
    MLKFaceContour *leftEyebrowTopContour = [face contourOfType:MLKFaceContourTypeLeftEyebrowTop];
    for (MLKVisionPoint *point in leftEyebrowTopContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.orangeColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *leftEyebrowBottomContour =
    [face contourOfType:MLKFaceContourTypeLeftEyebrowBottom];
    for (MLKVisionPoint *point in leftEyebrowBottomContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.orangeColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *rightEyebrowTopContour = [face contourOfType:MLKFaceContourTypeRightEyebrowTop];
    for (MLKVisionPoint *point in rightEyebrowTopContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.orangeColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *rightEyebrowBottomContour =
    [face contourOfType:MLKFaceContourTypeRightEyebrowBottom];
    for (MLKVisionPoint *point in rightEyebrowBottomContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.orangeColor
                               radius:MLKSmallDotRadius];
    }
    
    // Eyes
    MLKFaceContour *leftEyeContour = [face contourOfType:MLKFaceContourTypeLeftEye];
    for (MLKVisionPoint *point in leftEyeContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.cyanColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *rightEyeContour = [face contourOfType:MLKFaceContourTypeRightEye];
    for (MLKVisionPoint *point in rightEyeContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.cyanColor
                               radius:MLKSmallDotRadius];
    }
    
    // Lips
    MLKFaceContour *upperLipTopContour = [face contourOfType:MLKFaceContourTypeUpperLipTop];
    for (MLKVisionPoint *point in upperLipTopContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.redColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *upperLipBottomContour = [face contourOfType:MLKFaceContourTypeUpperLipBottom];
    for (MLKVisionPoint *point in upperLipBottomContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.redColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *lowerLipTopContour = [face contourOfType:MLKFaceContourTypeLowerLipTop];
    for (MLKVisionPoint *point in lowerLipTopContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.redColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *lowerLipBottomContour = [face contourOfType:MLKFaceContourTypeLowerLipBottom];
    for (MLKVisionPoint *point in lowerLipBottomContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.redColor
                               radius:MLKSmallDotRadius];
    }
    
    // Nose
    MLKFaceContour *noseBridgeContour = [face contourOfType:MLKFaceContourTypeNoseBridge];
    for (MLKVisionPoint *point in noseBridgeContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.yellowColor
                               radius:MLKSmallDotRadius];
    }
    MLKFaceContour *noseBottomContour = [face contourOfType:MLKFaceContourTypeNoseBottom];
    for (MLKVisionPoint *point in noseBottomContour.points) {
        CGPoint cgPoint = [self normalizedPointFromVisionPoint:point width:width height:height];
        [UIUtilities addCircleAtPoint:cgPoint
                               toView:self->_annotationOverlayView
                                color:UIColor.yellowColor
                               radius:MLKSmallDotRadius];
    }
}



#pragma mark- dealloc
- (void)dealloc
{
    NSLog(@"FaceViewController释放了");
    [self resetScreen];
    [self removeNotiObserver];
}

- (void)resetScreen
{
    [[UIScreen mainScreen] setBrightness:self.originBrightness];
    [[UIScreen mainScreen] setWantsSoftwareDimming:NO];
}

@end
