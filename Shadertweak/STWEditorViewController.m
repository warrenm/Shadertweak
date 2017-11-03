
#import "STWEditorViewController.h"
#import "STWPopupMessageButton.h"
#import "STWInputAccessoryView.h"

static CGFloat STWEditorGutterWidth = 22.0;

@interface STWEditorViewController() <UITextViewDelegate>
@property (nonatomic, strong) UITextView *sourceTextView;
@property (nonatomic, strong) STWInputAccessoryView *accessoryView;
@property (nonatomic, strong) NSDictionary *defaultTextAttributes;
@property (nonatomic, strong) NSMutableArray *messageGutterButtons;
@end

@implementation STWEditorViewController
@synthesize document=_document;

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        NSDictionary *traits = @{ UIFontSymbolicTrait : @(UIFontDescriptorTraitMonoSpace) };
        NSDictionary *preferredFontAttributes = @{ UIFontDescriptorFamilyAttribute : @"Menlo",
                                                   UIFontDescriptorTraitsAttribute : traits };
        UIFontDescriptor *fontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:preferredFontAttributes];

        NSSet *mandatoryKeys = [NSSet setWithObjects:
                                UIFontDescriptorTraitsAttribute, nil];

        NSArray *monospaceFaces = [fontDescriptor matchingFontDescriptorsWithMandatoryKeys:mandatoryKeys];

        UIFont *defaultFont = [UIFont fontWithDescriptor:[monospaceFaces firstObject] size:16];

        _defaultTextAttributes = @{ NSFontAttributeName : defaultFont,
                                    NSForegroundColorAttributeName : [UIColor colorWithWhite:0.8 alpha:1.0] };

        _messageGutterButtons = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [_document removeObserver:self forKeyPath:kLastCompilationErrorsKeyPath context:nil];
}

- (void)loadView {
    [super loadView];
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
//    self.view.backgroundColor = [UIColor clearColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.sourceTextView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.sourceTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sourceTextView.delegate = self;
    self.sourceTextView.backgroundColor = [UIColor colorWithRed:31/255.0 green:32/255.0 blue:41/255.0 alpha:1.0];
    self.sourceTextView.editable = YES;
    self.sourceTextView.selectable = YES;
    self.sourceTextView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.sourceTextView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.sourceTextView.allowsEditingTextAttributes = NO;
    self.sourceTextView.attributedText = [[NSAttributedString alloc] initWithString:@""
                                                                         attributes:self.defaultTextAttributes];
    self.sourceTextView.textContainerInset = UIEdgeInsetsMake(10, STWEditorGutterWidth, 0, 0);
    self.sourceTextView.keyboardAppearance = UIKeyboardAppearanceDark;

//    self.sourceTextView.inputAssistantItem

//    leadingBarButtonGroups trailingBarButtonGroups

    [self.view addSubview:self.sourceTextView];

    self.accessoryView = [[STWInputAccessoryView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.sourceTextView.inputAccessoryView = self.accessoryView;

    [self.view setNeedsLayout];
}

- (void)updateViewConstraints {
    [super updateViewConstraints];
    NSArray<NSLayoutConstraint *> *constraints = @[
        [NSLayoutConstraint constraintWithItem:self.sourceTextView
                                    attribute:NSLayoutAttributeWidth
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeWidth
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sourceTextView
                                    attribute:NSLayoutAttributeCenterX
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeCenterX
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sourceTextView
                                    attribute:NSLayoutAttributeTop
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeTop
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sourceTextView
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.view
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0
                                      constant:0.0],
    ];

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)setDocument:(STWDocument *)document {
    [_document removeObserver:self forKeyPath:kLastCompilationErrorsKeyPath context:nil];

    _document = document;
    [_document addObserver:self
                forKeyPath:kLastCompilationErrorsKeyPath
                   options:NSKeyValueObservingOptionNew
                   context:nil];

    self.sourceTextView.attributedText = [[NSAttributedString alloc] initWithString:document.fragmentSource
                                                                         attributes:self.defaultTextAttributes];

    [self restyleSourceText];

    [self updateGutterViewsWithMessages:_document.lastCompilationErrors];
}


- (BOOL)styleMatchesForRegularExpression:(NSRegularExpression *)regex
               inMutableAttributedString:(NSMutableAttributedString *)attributedString
                               withColor:(UIColor *)color
{
    __block BOOL didReplace = NO;

    NSMutableDictionary *literalAttributes = [self.defaultTextAttributes mutableCopy];
    literalAttributes[NSForegroundColorAttributeName] = color;

    [regex enumerateMatchesInString:attributedString.string
                            options:0
                              range:NSMakeRange(0, attributedString.length)
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
     {
         if (result.resultType == NSTextCheckingTypeRegularExpression) {
             [attributedString setAttributes:literalAttributes range:result.range];
             didReplace = YES;
         }
     }];

    return didReplace;
}

- (void)restyleSourceText {
    NSMutableAttributedString *mutableSource = [[NSMutableAttributedString alloc] initWithString:self.sourceTextView.attributedText.string
                                                                                      attributes:self.defaultTextAttributes];

    NSError *error = nil;
    NSRegularExpression *literalNumberRegEx = [NSRegularExpression regularExpressionWithPattern:@"\\b[\\+\\-]?\\d+(\\.\\d*)?[hf]?\\b"
                                                                                        options:0
                                                                                          error:&error];
    if (error) {
        NSLog(@"Error compiling regex: %@", error.localizedDescription);
    }

    NSArray *keywords = @[@"__dummy__",
                          @"using", @"namespace", @"struct", @"const", @"thread",
                          @"class", @"public", @"private", @"protected", @"auto",
                          @"static", @"threadgroup", @"device", @"constant", @"constexpr",
                          @"texture", @"texture2d", @"sampler", @"texture3d",
                          @"coord", @"normalized", @"filter", @"linear", @"nearest",
                          @"address", @"repeat", @"clamp_to_zero", @"clamp_to_edge",
                          @"vertex", @"fragment", @"kernel", @"void",
                          @"buffer", @"texture2d", @"sampler", @"stage_in",
                          @"int", @"int2", @"int3", @"int4",
                          @"uint", @"uint2", @"uint3", @"uint4",
                          @"half", @"half2", @"half3", @"half4",
                          @"half2x2", @"half3x3", @"half4x4",
                          @"float", @"float2", @"float3", @"float4",
                          @"float2x2", @"float3x3", @"float4x4",
                          @"if", @"for", @"while", @"do", @"return",
                          @"break", @"continue",
                          @"__dummy__"];

    NSArray *functions = @[@"__dummy__",
                           @"abs", @"fabs", @"cos", @"sin", @"tan", @"atan2",
                           @"pow", @"powr", @"log", @"exp", @"sqrt",
                           @"min", @"max", @"floor", @"ceil",
                           @"dot", @"cross", @"normalize", @"length", @"length_squared",
                           @"saturate", @"smoothstep", @"mix",
                           @"__dummy__",];

    NSString *keywordPattern = [keywords componentsJoinedByString:@"\\b|\\b"];

    NSRegularExpression *keywordRegEx = [NSRegularExpression regularExpressionWithPattern:keywordPattern
                                                                                  options:0
                                                                                    error:&error];

    NSString *functionPattern = [functions componentsJoinedByString:@"\\b|\\b"];

    NSRegularExpression *functionRegEx = [NSRegularExpression regularExpressionWithPattern:functionPattern
                                                                                   options:0
                                                                                     error:&error];

    BOOL textChanged = NO;

    UIColor *literalColor = [UIColor colorWithRed:20/255.0 green:156/255.0 blue:146/255.0 alpha:1.0];
    textChanged |= [self styleMatchesForRegularExpression:literalNumberRegEx
                                inMutableAttributedString:mutableSource
                                                withColor:literalColor];

    UIColor *functionColor = [UIColor colorWithRed:14/255.0 green:184/255.0 blue:46/255.0 alpha:1.0];
    textChanged |= [self styleMatchesForRegularExpression:functionRegEx
                                inMutableAttributedString:mutableSource
                                                withColor:functionColor];

    UIColor *keywordColor = [UIColor colorWithRed:215/255.0 green:0/255.0 blue:143/255.0 alpha:1.0];
    textChanged |= [self styleMatchesForRegularExpression:keywordRegEx
                                inMutableAttributedString:mutableSource
                                                withColor:keywordColor];

    if (textChanged) {
        self.sourceTextView.attributedText = mutableSource;
        self.sourceTextView.typingAttributes = self.defaultTextAttributes;
    }
}

// http://stackoverflow.com/a/3785752/155187
- (NSRange)rangeOfString:(NSString *)substring
                inString:(NSString *)string
             atOccurence:(NSInteger)occurence
{
    NSInteger currentOccurence = 0;
    NSRange rangeToSearchWithin = NSMakeRange(0, string.length);

    for (;;)
    {
        NSRange searchResult = [string rangeOfString:substring
                                             options:0
                                               range:rangeToSearchWithin];

        if (searchResult.location == NSNotFound) {
            return searchResult;
        }

        if (currentOccurence == occurence) {
            return searchResult;
        }

        ++currentOccurence;

        NSInteger newLocationToStartAt = searchResult.location + searchResult.length;
        rangeToSearchWithin = NSMakeRange(newLocationToStartAt, string.length - newLocationToStartAt);
    }
}

- (CGPoint)sourceViewGutterPointForMessage:(STWCompilerMessage *)message {
    NSInteger lineNumberOffset = self.document.fragmentShaderLineNumberBias;

    NSInteger fragmentLineNumber = message.lineNumber + lineNumberOffset;

    NSRange rangeOfPrecedingNewline = [self rangeOfString:@"\n"
                                                 inString:self.sourceTextView.text
                                              atOccurence:fragmentLineNumber - 1];

    if (rangeOfPrecedingNewline.location == NSNotFound) {
        rangeOfPrecedingNewline = NSMakeRange(0, 1);
    }

    NSInteger offendingCharacterIndex = rangeOfPrecedingNewline.location + message.columnNumber;

    UITextPosition *errorStartPosition = [self.sourceTextView positionFromPosition:self.sourceTextView.beginningOfDocument
                                                                           offset:offendingCharacterIndex];

    UITextPosition *errorStartPositionPlusOne = [self.sourceTextView positionFromPosition:errorStartPosition offset:1];

    UITextRange *textRangeForError = [self.sourceTextView textRangeFromPosition:errorStartPosition
                                                                    toPosition:errorStartPositionPlusOne];

    CGRect offendingCharacterRect = [self.sourceTextView firstRectForRange:textRangeForError];

    CGFloat y = floor(CGRectGetMidY(offendingCharacterRect) - STWPopupMessageButtonSize * 0.5);

    CGPoint gutterPoint = CGPointMake(2, y);

    return gutterPoint;
}

- (void)updateGutterViewsWithMessages:(NSArray<STWCompilerMessage *> *)messages {

    [self.messageGutterButtons makeObjectsPerformSelector:@selector(removeFromSuperview)];

    [self.messageGutterButtons removeAllObjects];

    for (STWCompilerMessage *message in messages) {
        CGPoint buttonOrigin = [self sourceViewGutterPointForMessage:message];
        CGRect buttonRect = CGRectMake(buttonOrigin.x, buttonOrigin.y,
                                       STWPopupMessageButtonSize, STWPopupMessageButtonSize);
        STWPopupMessageButton *button = [[STWPopupMessageButton alloc] initWithFrame:buttonRect];
        button.style = message.severity == STWCompilerMessageSeverityWarning ?
            STWPopupMessageButtonTypeWarning : STWPopupMessageButtonTypeError;
        button.message = message.message;
        button.popupPresentingViewController = self;
        [self.sourceTextView addSubview:button];
        [self.messageGutterButtons addObject:button];
    }
}

- (void)viewDidLayoutSubviews {
    [self updateGutterViewsWithMessages:self.document.lastCompilationErrors];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:kLastCompilationErrorsKeyPath] && [object isKindOfClass:[STWDocument class]]) {
        NSArray *messages = [object lastCompilationErrors];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateGutterViewsWithMessages:messages];

        });
        return;
    }

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}


#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView
shouldChangeTextInRange:(NSRange)replacementRange
 replacementText:(NSString *)replacementText
{
// Auto-indent isn't nearly robust enough to use right now.
#if 0
    // Auto-indent algorithm
    // Are we typing/inserting a newline?
    if ([replacementText isEqualToString:@"\n"]) {
        NSString *currentText = textView.text;
        // Look backward to find the start of the line that is terminated by this newline
        NSRange precedingNewline = [currentText rangeOfString:@"\n"
                                               options:NSBackwardsSearch
                                                 range:NSMakeRange(0, replacementRange.location + replacementRange.length - 1)];

        // If we don't find a preceding newline, we're at the start of the document; assume that's the case for a moment
        NSInteger startOfPrecedingLine = 0;

        // If we did find a preceding newline, locate its first character's offset
        if (precedingNewline.location != NSNotFound) {
            startOfPrecedingLine = precedingNewline.location + precedingNewline.length;
        }

        __block NSInteger whitespaceCount = 0;
        // Enumerate the grapheme clusters of the string, looking for leading whitespace
        NSRange lineRange = NSMakeRange(startOfPrecedingLine, replacementRange.location - startOfPrecedingLine);
        [currentText enumerateSubstringsInRange:lineRange
                                          options:NSStringEnumerationByComposedCharacterSequences
                                       usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
        {
            // If we find whitespace, increment the count of leading whitespace characters
            if ([substring isEqualToString:@" "] || [substring isEqualToString:@"\t"]) {
                whitespaceCount = substringRange.location - startOfPrecedingLine + 1;
            } else {
                // If we find something that's not whitespace, we've seen all of the leading whitespace, so we stop
                *stop = YES;
            }
        }];

        // If the preceding line did in fact have leading whitespace,
        if (whitespaceCount > 0) {
            // Get the substring of the preceding line that contains the leading whitespace,
            // so that we honor whatever mix of tabs and spaces we find there, avoiding religious wars
            NSString *leadingWhitespace = [currentText substringWithRange:NSMakeRange(startOfPrecedingLine, whitespaceCount)];
            // Append the whitespace to the newline to get the new text to insert
            replacementText = [replacementText stringByAppendingString:leadingWhitespace];
            // Insert the duplicate whitespace string at the start of the new line and replace the text view's string
            NSString *newText = [currentText stringByReplacingCharactersInRange:replacementRange
                                                                     withString:replacementText];

            textView.text = newText;

            UITextPosition *insertionPosition = [textView positionFromPosition:textView.beginningOfDocument
                                                                        offset:replacementRange.location + replacementText.length];
            textView.selectedTextRange = [textView textRangeFromPosition:insertionPosition toPosition:insertionPosition];

            [self textViewDidChange:textView];
            // Since we're manually updating the text view, skip the update that would be done for us
            return NO;
        }
    }
#endif
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    // Suspend scrolling so the text view doesn't jump around as we adjust the source string
    textView.scrollEnabled = NO;

    // Save cursor position and selection range to restore after restyling text
    UITextRange *selectedRange = textView.selectedTextRange;

    [self restyleSourceText];
    self.document.fragmentSource = textView.attributedText.string;

    // Restore previous selection
    textView.selectedTextRange = selectedRange;

    // Re-enable scrolling
    textView.scrollEnabled = YES;
}

@end
