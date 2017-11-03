@import UIKit;

extern const CGFloat STWPopupMessageButtonSize;

typedef NS_ENUM(NSInteger, STWPopupMessageButtonStyle) {
    STWPopupMessageButtonTypeInfo,
    STWPopupMessageButtonTypeWarning,
    STWPopupMessageButtonTypeError,
};

@interface STWPopupMessageButton : UIView

@property (nonatomic, strong) UIViewController *popupPresentingViewController;

@property (nonatomic, assign) STWPopupMessageButtonStyle style;
@property (nonatomic, copy) NSString *message;

- (instancetype)initWithFrame:(CGRect)frame;

@end
