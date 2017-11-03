
@import UIKit;
#import "STWSceneViewController.h"
#import "STWEditorViewController.h"
#import "STWDocument.h"

typedef enum {
    STWSplitViewOrientationHorizontal,
    STWSplitViewOrientationVertical,
} STWSplitViewOrientation;

@interface STWProjectViewController : UIViewController

@property (nonatomic, assign) STWSplitViewOrientation orientation;
@property (nonatomic, strong) STWSceneViewController *sceneViewController;
@property (nonatomic, strong) STWEditorViewController *editorViewController;

@property (nonatomic, strong) STWDocument *document;

@end
