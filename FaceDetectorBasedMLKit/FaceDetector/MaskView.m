//
//  MaskView.m
//  TestApp
//
//  Created by zgy on 2024/7/26.
//

#import "MaskView.h"

@interface MaskView()


@property (weak, nonatomic) IBOutlet NSLayoutConstraint *circleBaseViewWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *circleViewWidth;


@property (weak, nonatomic) IBOutlet UIView *circleBaseView;
@property (weak, nonatomic) IBOutlet UIView *circleView;


@property (weak, nonatomic) IBOutlet UIButton *tipBtn;


@end

#define kFDColorWithHex(hexValue) \
[UIColor colorWithRed:((float)((hexValue & 0xFF0000) >> 16)) / 255.0 \
green:((float)((hexValue & 0xFF00) >> 8)) / 255.0 \
blue:((float)(hexValue & 0xFF)) / 255.0 alpha:1.0]

@implementation MaskView

+ (instancetype)maskView
{
    NSArray *arr = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self) owner:nil options:nil];
    return [arr lastObject];
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    
    int w0 = [self getNearestEven:UIScreen.mainScreen.bounds.size.width * 0.8];
    
    
    int w1 = [self getNearestEven:w0 - 10];
    _circleBaseViewWidth.constant = w0;
    _circleViewWidth.constant = w1;
    
    _circleBaseView.layer.cornerRadius = w0 * 0.5;
    _circleBaseView.clipsToBounds = YES;
    
    _circleView.layer.cornerRadius = w1 * 0.5;
    _circleView.clipsToBounds = YES;
    

    
}

- (void)updateTip:(NSString *)tip isValid:(BOOL)valid
{
    UIColor *color = [UIColor whiteColor];
    if (valid) {
        color = kFDColorWithHex(0x1ba784);
    }
    [_tipBtn setTitle:tip forState:UIControlStateNormal];
    [_tipBtn setTitleColor:color forState:UIControlStateNormal];
}

- (int)getNearestEven:(CGFloat)old
{
    int res = (int)old;
    if (res % 2 != 0) {
        res++;
    }
    return res;
}

@end
