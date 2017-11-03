
#import "STWPopupMessageButton.h"

const CGFloat STWPopupMessageButtonSize = 16.0;

static const CGFloat STWMessagePopupMaximumWidth = 320.0;
static const CGFloat STWMessagePopupMinimumHeight = 44.0;

@interface STWPopupMessageViewController : UIViewController
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, copy) NSDictionary *messageTextAttributes;
@end

@implementation STWPopupMessageViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        NSDictionary *traits = @{ UIFontSymbolicTrait : @(UIFontDescriptorTraitMonoSpace) };
        NSDictionary *preferredFontAttributes = @{ UIFontDescriptorFamilyAttribute : @"Menlo",
                                                   UIFontDescriptorTraitsAttribute : traits };
        UIFontDescriptor *fontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:preferredFontAttributes];

        NSSet *mandatoryKeys = [NSSet setWithObjects:
                                UIFontDescriptorTraitsAttribute, nil];

        NSArray *monospaceFaces = [fontDescriptor matchingFontDescriptorsWithMandatoryKeys:mandatoryKeys];

        UIFont *defaultFont = [UIFont fontWithDescriptor:[monospaceFaces firstObject] size:14];

        _messageTextAttributes = @{ NSFontAttributeName : defaultFont,
                                    NSForegroundColorAttributeName : [UIColor colorWithWhite:0.12 alpha:1.0] };
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];

    CGRect labelBounds = self.view.bounds;
    _messageLabel = [[UILabel alloc] initWithFrame:labelBounds];
    _messageLabel.opaque = NO;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.text = @"(no message)";
    _messageLabel.numberOfLines = 0;
    [self.view addSubview:_messageLabel];
}

- (void)setMessage:(NSString *)message {
    [self loadViewIfNeeded];

    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:message attributes:self.messageTextAttributes];
    self.messageLabel.attributedText = attributedMessage;

    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    CGRect stringBounds = [self.message boundingRectWithSize:CGSizeMake(STWMessagePopupMaximumWidth - 20, CGFLOAT_MAX)
                                                     options:options
                                                  attributes:self.messageTextAttributes
                                                     context:nil];
    self.preferredContentSize = CGSizeMake(STWMessagePopupMaximumWidth, stringBounds.size.height + STWMessagePopupMinimumHeight);
    self.messageLabel.frame = CGRectMake(10, 10, stringBounds.size.width, stringBounds.size.height);
}

- (NSString *)message {
    return self.messageLabel.text;
}

@end

@interface STWPopupMessageButton () <UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIPopoverPresentationController *popoverPresentationController;
@end

@implementation STWPopupMessageButton

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _button = [[UIButton alloc] initWithFrame:self.bounds];
        _button.contentMode = UIViewContentModeScaleAspectFit;
        [_button addTarget:self
                    action:@selector(buttonTapped:)
          forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];
        [self setStyle:STWPopupMessageButtonTypeError];
    }
    return self;
}

- (void)setStyle:(STWPopupMessageButtonStyle)style {
    _style = style;

    UIImage *image = nil;

    switch (_style) {
        case STWPopupMessageButtonTypeInfo:
            image = [UIImage imageNamed:@"gutter-icon-info"];
            break;
        case STWPopupMessageButtonTypeWarning:
            image = [UIImage imageNamed:@"gutter-icon-warning"];
            break;
        case STWPopupMessageButtonTypeError:
            image = [UIImage imageNamed:@"gutter-icon-error"];
            break;
    }

    if (image == nil) {
        NSLog(@"Don't have icon for message style %d", (int)style);
    }

    [_button setImage:image forState:UIControlStateNormal];
}

- (UIViewController *)presentedViewController {
    STWPopupMessageViewController *messageViewController = [[STWPopupMessageViewController alloc] initWithNibName:nil
                                                                                                           bundle:nil];

    messageViewController.message = self.message;
    messageViewController.modalPresentationStyle = UIModalPresentationPopover;
    return messageViewController;
}

- (void)presentMessagePopup {
    UIViewController *messageViewController = [self presentedViewController];

    [self.popupPresentingViewController presentViewController:messageViewController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = messageViewController.popoverPresentationController;
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionRight;
    presentationController.sourceView = self.button;
    presentationController.sourceRect = CGRectMake(0, STWPopupMessageButtonSize * 0.5, 1, 1);
    presentationController.delegate = self;
}

#pragma mark - Actions

- (IBAction)buttonTapped:(id)sender {
    [self presentMessagePopup];
}

#pragma mark - Popover Presentation Controller

- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController {}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController { return YES; }

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    self.popoverPresentationController.delegate = nil;
    self.popoverPresentationController = nil;
}

@end
