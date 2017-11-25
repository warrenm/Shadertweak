@import UIKit;
@import Metal;

@interface STWSnapshotter : NSObject

+ (UIImage *)captureSnapshotOfSize:(CGSize)size
               renderPipelineState:(id<MTLRenderPipelineState>)renderPipelineState
                          textures:(NSArray *)textures
							  time:(float)time
						 deltaTime:(float)delta;

@end
