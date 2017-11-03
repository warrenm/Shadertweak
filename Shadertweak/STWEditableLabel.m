
#import "STWEditableLabel.h"

static const CGRect kInitialFrame = { .origin = { 0, 0 }, .size = { 320, 22 } };

@interface STWEditableLabel () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UITapGestureRecognizer *gestureRecognizer;
@property (nonatomic, copy) NSDictionary *labelTextAttribs;

@end

@implementation STWEditableLabel

//@synthesize text=_text;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInitWithFrame:kInitialFrame];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInitWithFrame:frame];
    }
    return self;
}

- (void)commonInitWithFrame:(CGRect)frame {
    _textField = [[UITextField alloc] initWithFrame:frame];
    _textField.translatesAutoresizingMaskIntoConstraints = NO;
    _textField.textAlignment = NSTextAlignmentCenter;
    _textField.autocorrectionType = UITextAutocorrectionTypeNo;
    _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _textField.delegate = self;
    [self addSubview:_textField];

    [self setNeedsLayout];

    _labelTextAttribs = @{ NSFontAttributeName : [UIFont boldSystemFontOfSize:16],
                           NSForegroundColorAttributeName : [UIColor whiteColor] };
}

- (void)updateConstraints {
    [super updateConstraints];
    NSArray<NSLayoutConstraint *> *textFieldHConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-[textField]-|"
                                                                                         options:0
                                                                                         metrics:@{}
                                                                                           views:@{ @"textField" : _textField }];
    NSArray<NSLayoutConstraint *> *textFieldVConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[textField]|"
                                                                                                   options:0
                                                                                                   metrics:@{}
                                                                                                     views:@{ @"textField" : _textField }];

    [NSLayoutConstraint activateConstraints:textFieldHConstraints];
    [NSLayoutConstraint activateConstraints:textFieldVConstraints];
}

- (void)setText:(NSString *)text {
    NSAttributedString *attributedText = [[NSAttributedString alloc] initWithString:text attributes:self.labelTextAttribs];
    self.textField.attributedText = attributedText;
}

- (NSString *)text {
    return [self.textField.attributedText string];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    UITextRange *range = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];
    [textField setSelectedTextRange:range];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([self.delegate respondsToSelector:@selector(editableLabel:textDidChange:)]) {
        NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
        [self.delegate editableLabel:self textDidChange:newText];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if ([self.delegate respondsToSelector:@selector(editableLabelDidEndEditing:)]) {
        [self.delegate editableLabelDidEndEditing:self];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

@end
