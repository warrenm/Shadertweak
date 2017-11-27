@import UIKit;
@import Metal;
#import "STWMetalContext.h"
#import "STWCompilerDiagnostics.h"

extern NSString *const kLibraryKeyPath;
extern NSString *const kLastCompilationErrorsKeyPath;

extern NSString *const STWDocumentDidSaveNotificationName;

typedef NS_ENUM(NSInteger, SWTGeometryType) {
    SWTGeometryTypeFullscreenQuad,
//    SWTGeometryTypeSphere,
//    SWTGeometryTypeBox,
//    SWTGeometryTypeTorus,
//    SWTGeometryTypeCustomMesh = 127,
};

@interface STWDocument : UIDocument

// Persisted properties

@property (nonatomic, assign) NSUInteger documentFormatVersion;
@property (nonatomic, copy) NSString *fragmentSource;
@property (nonatomic, assign) SWTGeometryType geometryType;
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, readwrite) int resolutionScale;

// TODO: Add properties such as bound known textures, pointers to user-loaded textures, custom models, etc.

// Non-persisted properties

@property (nonatomic, strong) STWMetalContext *metalContext;

@property (nonatomic, strong) id<MTLLibrary> currentLibrary;
@property (nonatomic, strong) id<MTLLibrary> lastKnownGoodLibrary;
@property (nonatomic, assign) NSTimeInterval lastCompilationStartTime;

/// Holds the set of Metal shader compiler warnings/errors produced by the last failed compilation, if any.
/// Cleared when a library is successfully produced, so either this property or `currentLibrary` will always
/// be nil (sometimes both).
@property (nonatomic, strong) NSArray<STWCompilerMessage *> *lastCompilationErrors;

@property (nonatomic, readonly) NSInteger fragmentShaderLineNumberBias;
@property (nonatomic, strong) NSString *lastKnownGoodFragmentSource;
@property (nonatomic, strong) NSString *preambleSource;

@end
