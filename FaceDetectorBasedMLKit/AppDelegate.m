//
//  AppDelegate.m
//  FaceDetectorBasedMLKit
//
//  Created by zgy on 2024/7/31.
//

#import "AppDelegate.h"
#import "ImageDetector.h"


@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    
//    for (int i = 1; i < 10; i ++) {
//        UIImage *img = [UIImage imageNamed:@(i).stringValue];
//        if (img) {
//            [self checkImg:img];
//        }
//    }
    
    
    NSArray *arr = @[@"0219", @"0220", @"0227", @"0228", @"0229"];
    for (int i = 0; i < arr.count; i++) {
        UIImage *img = [UIImage imageNamed:arr[i]];
        if (img) {
            [self checkImg:img];
        }
        
    }
    
    
    
    
    
    return YES;
}

- (void)checkImg:(UIImage *)image
{
    struct ImageQualityResult res = [[ImageDetector shared] checkImageQuality:image];
    NSLog(@"passed: %d, brightness: %f, blur: %f, minSize: %d", res.passed, res.brightness, res.blur, res.minSize);
}



#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
