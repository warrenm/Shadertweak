@import UIKit;
#import "STWSceneView.h"
#import "STWDocument.h"

@interface STWSceneViewController : UIViewController

@property (nonatomic, weak) STWSceneView *sceneView;
@property (nonatomic, strong) STWDocument *document;

@property (nonatomic, readwrite) BOOL isRunning;

@end
