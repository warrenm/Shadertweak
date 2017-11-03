
#import "STWInputAccessoryView.h"

@implementation STWInputAccessoryButton

@end

@implementation STWInputAccessoryView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    return [self commonInit];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    return [self commonInit];
}

- (instancetype)commonInit {
    static CGFloat bgGray = 20/255.0;
    [super setBackgroundColor:[UIColor colorWithRed:bgGray green:bgGray blue:bgGray alpha:1.0]];

    NSArray *buttonTitles = @[@"{", @"}", @"[", @"]", @"(", @")", @"<", @">", @";", @"*", @"/", @"="];
    NSMutableArray *buttons = [NSMutableArray array];
    for (int i = 0; i < buttonTitles.count; ++i) {
        STWInputAccessoryButton *button = [[STWInputAccessoryButton alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        [buttons addObject:button];
    }

    _buttons = [buttons copy];

    return self;
}

@end
