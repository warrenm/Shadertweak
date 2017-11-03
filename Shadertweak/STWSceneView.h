
@import MetalKit;
#import "STWMetalContext.h"

@interface STWSceneView : MTKView

@property (nonatomic, strong) STWMetalContext *metalContext;

@property (nonatomic, strong) id<MTLLibrary> library;

- (instancetype)initWithFrame:(CGRect)frameRect context:(STWMetalContext *)metalContext;

- (UIImage *)captureSnapshotAtSize:(CGSize)imageSize;

@end
