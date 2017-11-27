
#import "STWProjectViewController.h"
#import "STWEditableLabel.h"
#import "STWTextureSelectionViewController.h"

static CGSize STWSnapshotCaptureSize = { .width = 683, .height = 512 };

@interface STWProjectViewController () <STWEditableLabelDelegate>
@property (nonatomic, strong) UILayoutGuide *keyboardLayoutGuide;
@property (nonatomic, strong) NSLayoutConstraint *keyboardHeightConstraint;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *geometryButton, *texturesButton, *pauseButton, *playButton, *resButton, *toolbarSpacer;
@property (nonatomic, readwrite) int selectedResIndex;
@property (nonatomic, strong) STWEditableLabel *titleLabel;
@end

@implementation STWProjectViewController
@synthesize document=_document;

-(instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)loadView {
    [super loadView];
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
		// Set initial res to 2x (retina)
	self.selectedResIndex = 0;
    
    self.toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    [self.view addSubview:self.toolbar];

    self.sceneViewController = [[STWSceneViewController alloc] initWithNibName:nil bundle:nil];
    self.editorViewController = [[STWEditorViewController alloc] initWithNibName:nil bundle:nil];

    [self addChildViewController:self.sceneViewController];
    [self addChildViewController:self.editorViewController];

    [self.view addSubview:self.sceneViewController.view];
    [self.view addSubview:self.editorViewController.view];

    self.keyboardLayoutGuide = [UILayoutGuide new];
    [self.view addLayoutGuide:self.keyboardLayoutGuide];
    [self.keyboardLayoutGuide.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.keyboardLayoutGuide.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.keyboardLayoutGuide.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    self.keyboardHeightConstraint = [self.keyboardLayoutGuide.heightAnchor constraintEqualToConstant:0.0];
    self.keyboardHeightConstraint.active = YES;
    
    self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [self.toolbar.bottomAnchor constraintEqualToAnchor:self.keyboardLayoutGuide.topAnchor].active = YES;

    [self configureToolbar];

    self.titleLabel = [[STWEditableLabel alloc] initWithFrame:CGRectMake(0, 0, 320, 22)];
    self.titleLabel.delegate = self;
    self.navigationItem.titleView = self.titleLabel;
    self.titleLabel.text = @"New Document";

    [self.view setNeedsUpdateConstraints];
}

- (void)configureToolbar {
	UIImage *geometryIcon = [UIImage imageNamed:@"geometry-icon"];
	self.geometryButton = [[UIBarButtonItem alloc] initWithImage:geometryIcon
														   style:UIBarButtonItemStylePlain
														  target:self
														  action:@selector(showGeometrySelectionPopup:)];
	self.geometryButton.enabled = NO;
	UIImage *texturesIcon = [UIImage imageNamed:@"texture-icon"];
	self.texturesButton = [[UIBarButtonItem alloc] initWithImage:texturesIcon
														   style:UIBarButtonItemStylePlain
														  target:self
														  action:@selector(showTextureSelectionPopup:)];
	self.pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseRunning)];
	self.playButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(resumePlayback)];
	
	self.resButton = [[UIBarButtonItem alloc] initWithTitle:@"Res: 2x" style:UIBarButtonItemStylePlain target:self action:@selector(switchRes)];
	
	self.toolbarSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	self.toolbarSpacer.width = 8.0;
	
	[self updateToolbarForPlaying:YES];
}

-(void)updateToolbarForPlaying:(BOOL)playing {
	NSArray *buttonItems = @[ self.geometryButton, self.toolbarSpacer, self.texturesButton, self.self.toolbarSpacer, playing ? self.pauseButton  : self.playButton, self.toolbarSpacer, self.resButton];
	
	[self.toolbar setItems:buttonItems];
	
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self registerForKeyboardNotifications];
}

- (void)viewWillDisappear:(BOOL)animated {
		//	Get the thumbnail before it's off screen so we can use view snapshotting
	UIImage *thumbnailImage = [self.sceneViewController.sceneView captureSnapshotAtSize:STWSnapshotCaptureSize];
	self.document.thumbnailImage = thumbnailImage;
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self unregisterForKeyboardNotifications];

    [self closeDocument];

}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)updateViewConstraints {
    [super updateViewConstraints];

    NSArray<NSLayoutConstraint *> *constraints = @[
        [NSLayoutConstraint constraintWithItem:self.sceneViewController.view
                                    attribute:NSLayoutAttributeWidth
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeWidth
                                   multiplier:0.5 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.sceneViewController.view
                                    attribute:NSLayoutAttributeBottom
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.toolbar
                                    attribute:NSLayoutAttributeTop
                                   multiplier:1.0 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.view
                                    attribute:NSLayoutAttributeLeading
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.sceneViewController.view
                                    attribute:NSLayoutAttributeLeading
                                   multiplier:1.0 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.sceneViewController.view
                                    attribute:NSLayoutAttributeTop
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.topLayoutGuide
                                    attribute:NSLayoutAttributeBottom
                                   multiplier:1.0 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.editorViewController.view
                                    attribute:NSLayoutAttributeWidth
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.view
                                    attribute:NSLayoutAttributeWidth
                                   multiplier:0.5 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.editorViewController.view
                                     attribute:NSLayoutAttributeBottom
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.toolbar
                                     attribute:NSLayoutAttributeTop
                                    multiplier:1.0 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.sceneViewController.view
                                    attribute:NSLayoutAttributeTrailing
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:self.editorViewController.view
                                    attribute:NSLayoutAttributeLeading
                                   multiplier:1.0 constant:0.0],

        [NSLayoutConstraint constraintWithItem:self.editorViewController.view
                                     attribute:NSLayoutAttributeTop
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self.topLayoutGuide
                                     attribute:NSLayoutAttributeBottom
                                    multiplier:1.0 constant:0.0],

    ];

    [self.view addConstraints:constraints];
}

- (void)setDocument:(STWDocument *)document {
    _document = document;
    self.titleLabel.text = _document.localizedName;
    
    self.sceneViewController.document = document;
    self.editorViewController.document = document;
	
	int resScale = document.resolutionScale;
	if (resScale < 3 && resScale > 0) {
		self.selectedResIndex = resScale;
		[self updateRes];
	}
}

- (void)closeDocument {

    NSURL *fileURL = self.document.fileURL;
    [self.document closeWithCompletionHandler:^(BOOL success) {
        if (success) {
            NSLog(@"Closed document at URL %@", fileURL);
        } else {
            NSLog(@"Could not close document at URL %@", fileURL);
        }
    }];

//    [self.document saveToURL:self.document.fileURL
//            forSaveOperation:UIDocumentSaveForOverwriting
//           completionHandler:^(BOOL success)
//     {
//         if (success)
//             NSLog(@"Finished saving");
//         else
//             NSLog(@"Failed to save!");
//     }];
}

- (void)editableLabelDidEndEditing:(STWEditableLabel *)label {

    if (!self.document) {
        return;
    }

    if (!self.document.fileURL) {
        return;
    }

    if (label.text.length == 0) {
        return;
    }

    NSURL *sourceURL = self.document.fileURL;

    [self renameDocument:self.document toName:label.text completionHandler:^(BOOL success, NSURL *newURL) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                STWDocument *newDocument = [[STWDocument alloc] initWithFileURL:newURL];
                [newDocument openWithCompletionHandler:^(BOOL success) {
                    if (!success) {
                        NSLog(@"Could not reopen document after moving");
                    }
                    self.document = newDocument;
                    if (![[NSFileManager defaultManager] removeItemAtURL:sourceURL error:nil]) {
                        NSLog(@"Could not remove old document. Sigh.");
                    }
                }];
            });
        }
    }];
}

- (void)renameDocument:(UIDocument *)document
                toName:(NSString *)newName
     completionHandler:(void (^)(BOOL success, NSURL *newURL))completionHandler
{
    NSURL *sourceURL = document.fileURL;

    // TODO: Verify uniqueness of new name
    NSURL *destinationURL = [[[document.fileURL URLByDeletingLastPathComponent]
                              URLByAppendingPathComponent:newName isDirectory:YES]
                             URLByAppendingPathExtension:@"stweak"];

    if ([sourceURL isEqual:destinationURL]) {
        return; // No-op
    }

    void (^renameBlock)() = ^void() {
        dispatch_queue_t backgroundQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);

        dispatch_async(backgroundQueue, ^(void) {
            NSError *error = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [fileCoordinator coordinateWritingItemAtURL:sourceURL
                                                options:NSFileCoordinatorWritingForMoving
                                       writingItemAtURL:destinationURL
                                                options:NSFileCoordinatorWritingForReplacing
                                                  error:&error
                                             byAccessor:^(NSURL *source, NSURL *dest)
             {
                 NSError *moveError = nil;
                 if (![fileManager moveItemAtURL:source toURL:dest error:&moveError]) {
                     NSLog(@"Error occurred when moving: %@", moveError.localizedDescription);
                     if(completionHandler) {
                         completionHandler(NO, nil);
                     }
                 } else {
                     NSLog(@"Moved document to %@", dest);
                     if(completionHandler) {
                         completionHandler(YES, destinationURL);
                     }
                 }
             }];
        });
    };

    if ((document.documentState & UIDocumentStateClosed) == 0) {
        renameBlock();
    } else {
        [document closeWithCompletionHandler:^(BOOL success) {
            if (success) {
                NSLog(@"Closed document for renaming at URL %@", sourceURL);
                renameBlock();
            }
        }];
    }
}

#pragma mark - Texture and geometry selection

- (IBAction)showTextureSelectionPopup:(id)sender {

    STWTextureSelectionViewController *textureSlotListVC = [[STWTextureSelectionViewController alloc] init];

    UINavigationController *textureSelectionNavController = [[UINavigationController alloc] initWithRootViewController:textureSlotListVC];

    

    UIColor *barColor = [UIColor whiteColor];
    [textureSelectionNavController.navigationBar setBarTintColor:barColor];
    [textureSelectionNavController.navigationBar setTranslucent:NO];

    textureSelectionNavController.modalPresentationStyle = UIModalPresentationPopover;
    textureSelectionNavController.preferredContentSize = CGSizeMake(320, 220);

    [self presentViewController:textureSelectionNavController animated:YES completion:nil];

    UIPopoverPresentationController *presentationController = textureSelectionNavController.popoverPresentationController;

    presentationController.barButtonItem = sender;
}

#pragma mark - Resolution settings

/**
 Cycles between 2x (retina), 1x (half retina), 2x (quarter) resolutions
 */
- (void)switchRes {
	self.selectedResIndex++;
	if (self.selectedResIndex > 2) { self.selectedResIndex = 0; }
	
	self.document.resolutionScale = self.selectedResIndex;
	[self updateRes];
}

- (void)updateRes {
	const NSArray *titles = @[@"Res: 2x", @"Res: 1x", @"Res: 0.5x"];
	const CGFloat scales[] = {2.0, 1.0, 0.5};
	
	[self.sceneViewController.sceneView updateResolutionScaling: scales[self.selectedResIndex]];
	self.resButton.title = titles[self.selectedResIndex];
}

#pragma mark - Pause / play

/**
 Pauses MTKView's automatic animation.
 */
- (void)pauseRunning {
	self.sceneViewController.isRunning = NO;
	[self updateToolbarForPlaying:NO];
}

/**
 Resumes MTKView's automatic animation.
 */
- (void)resumePlayback {
	self.sceneViewController.isRunning = YES;
	[self updateToolbarForPlaying:YES];
}

#pragma mark - Keyboard management

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardFrameWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
}

- (void)unregisterForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)keyboardFrameWillChange:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    CGRect keyboardFrameEnd = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrameEnd = [self.view convertRect:keyboardFrameEnd fromView:nil];

    [self.view layoutIfNeeded];
    self.keyboardHeightConstraint.constant = self.view.bounds.size.height - keyboardFrameEnd.origin.y;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL completed) {
    }];
}

- (void)keyboardWillHide:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    NSTimeInterval duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

//    CGRect keyboardFrameEnd = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
//    keyboardFrameEnd = [self.view convertRect:keyboardFrameEnd fromView:nil];

    [self.view layoutIfNeeded];
    self.keyboardHeightConstraint.constant = 0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL completed) {
    }];
}

@end
