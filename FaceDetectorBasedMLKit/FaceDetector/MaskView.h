//
//  MaskView.h
//  TestApp
//
//  Created by zgy on 2024/7/26.
//

#import <UIKit/UIKit.h>



@interface MaskView : UIView

@property (weak, nonatomic) IBOutlet UIView *previewView;

+ (instancetype)maskView;


- (void)updateTip:(NSString *)tip isValid:(BOOL)valid;

@end


