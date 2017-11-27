
#import "STWSceneViewController.h"

@implementation STWSceneViewController

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)dealloc {
    [_document removeObserver:self forKeyPath:kLibraryKeyPath context:nil];
}

- (void)loadView {
    [super loadView];
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    STWSceneView *sceneView = [[STWSceneView alloc] initWithFrame:self.view.bounds
                                                          context:[STWMetalContext defaultContext]];

    self.sceneView = sceneView;
    self.sceneView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.sceneView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:sceneView];
    [self.view setNeedsLayout];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.document = nil; // Fixes up last-known-good library KVO

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // This is awful, but in iOS 9, MTKView creates a retain cycle with its internal CADisplayLink
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] < 10.0) {
        [self.sceneView performSelector:NSSelectorFromString(@"release")];
    }
#pragma clang diagnostic pop
}

- (void)updateViewConstraints {
    [super updateViewConstraints];
    NSArray<NSLayoutConstraint *> *constraints = @[
        [NSLayoutConstraint constraintWithItem:self.sceneView
                                    attribute:NSLayoutAttributeWidth
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeWidth
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sceneView
                                    attribute:NSLayoutAttributeHeight
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeHeight
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sceneView
                                    attribute:NSLayoutAttributeCenterX
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeCenterX
                                   multiplier:1.0 constant:0.0],
        [NSLayoutConstraint constraintWithItem:self.sceneView
                                    attribute:NSLayoutAttributeCenterY
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeCenterY
                                   multiplier:1.0 constant:0.0],
    ];

    [self.view addConstraints:constraints];
}

- (void)setDocument:(STWDocument *)document {
    [_document removeObserver:self forKeyPath:kLibraryKeyPath context:nil];

    _document = document;
    [_document addObserver:self
                forKeyPath:kLibraryKeyPath
                   options:NSKeyValueObservingOptionNew
                   context:nil];
    self.sceneView.library = [_document lastKnownGoodLibrary];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:kLibraryKeyPath] && [object isKindOfClass:[STWDocument class]]) {
        self.sceneView.library = [object lastKnownGoodLibrary];
        return;
    }
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(void)setIsRunning:(BOOL)isRunning {
	self.sceneView.paused = !isRunning;
	self.sceneView.enableSetNeedsDisplay = !isRunning;
}

@end
