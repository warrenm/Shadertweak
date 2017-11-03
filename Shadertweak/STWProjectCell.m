#import "STWProjectCell.h"

@implementation STWProjectCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [self addSubview:_imageView];

    _label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    _label.text = @"Project Title";
    _label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    _label.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    _label.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    _label.shadowOffset = CGSizeMake(0, 1);
    _label.textAlignment = NSTextAlignmentCenter;
    _label.font = [UIFont systemFontOfSize:14 weight:0.4];
    [self addSubview:_label];

    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints {
    [super updateConstraints];

    [NSLayoutConstraint constraintWithItem:self.label
                                 attribute:NSLayoutAttributeLeading
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeLeading
                                multiplier:1.0 constant:0.0].active = YES;

    [NSLayoutConstraint constraintWithItem:self.label
                                 attribute:NSLayoutAttributeTrailing
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeTrailing
                                multiplier:1.0 constant:0.0].active = YES;

    [NSLayoutConstraint constraintWithItem:self.label
                                 attribute:NSLayoutAttributeBottom
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeBottom
                                multiplier:1.0 constant:0.0].active = YES;

    [NSLayoutConstraint constraintWithItem:self.label
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self
                                 attribute:NSLayoutAttributeHeight
                                multiplier:0.0 constant:30.0].active = YES;
}

@end
