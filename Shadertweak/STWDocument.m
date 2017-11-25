#import "STWDocument.h"

static NSString *const STWErrorDomain = @"net.warrenmoore.shadertweak";
NSString *const kLibraryKeyPath = @"lastKnownGoodLibrary";
NSString *const kLastCompilationErrorsKeyPath = @"lastCompilationErrors";

NSString *const STWDocumentDidSaveNotificationName = @"STWDocumentDidSaveNotification";

@interface STWDocument ()
@property (nonatomic, assign, getter=isDirty) BOOL dirty;
@end

@implementation STWDocument

- (instancetype)initWithFileURL:(NSURL *)url {
    if ((self = [super initWithFileURL:url])) {
        NSError *error = nil;
        NSURL *preambleURL = [[NSBundle mainBundle] URLForResource:@"Shaders-preamble"
                                                     withExtension:@"txt"];
        NSString *preambleSource = [NSString stringWithContentsOfURL:preambleURL
                                                            encoding:NSUTF8StringEncoding
                                                               error:&error];
        
        _preambleSource = preambleSource;
        
        NSURL *templateURL = [[NSBundle mainBundle] URLForResource:@"Shaders-template"
                                                     withExtension:@"txt"];
        NSString *templateSource = [NSString stringWithContentsOfURL:templateURL
                                                            encoding:NSUTF8StringEncoding
                                                               error:&error];
        
        _fragmentSource = templateSource;
        
        _metalContext = [STWMetalContext defaultContext];
        
        [self buildLibrary];
    }
    return self;
}

- (NSString *)localizedName
{
    NSString *filename = [self.fileURL lastPathComponent];
    NSString *name = [filename stringByDeletingPathExtension];
    return name;
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {
    
    NSFileWrapper *directoryWrapper = contents;
    
    NSDictionary *fileMap = [directoryWrapper fileWrappers];
    
    NSFileWrapper *shaderFileWrapper = fileMap[@"Shaders.metal"];
    
    if (shaderFileWrapper) {
        NSData *shaderData = [shaderFileWrapper regularFileContents];
        NSString *shaderSource = [[NSString alloc] initWithData:shaderData encoding:NSUTF8StringEncoding];
        if (!shaderSource) {
            return NO;
        } else {
            self.fragmentSource = shaderSource;
        }
    } else {
        if (outError) {
            *outError = [[NSError alloc] initWithDomain:STWErrorDomain
                                                   code:-1001
                                               userInfo: @{ NSLocalizedDescriptionKey : @"Could not find expected file Shaders.metal" }];
        }
        return NO;
    }

    NSFileWrapper *thumbnailFileWrapper = fileMap[@"Thumbnail@2x.png"];

    if (thumbnailFileWrapper) {
        NSData *thumbnailData = [thumbnailFileWrapper regularFileContents];
        UIImage *thumbnailImage = [UIImage imageWithData:thumbnailData scale:2.0];
        self.thumbnailImage = thumbnailImage;
    }
	
	NSFileWrapper *metadataFileWrapper = fileMap[@"Metadata.plist"];

	if (metadataFileWrapper) {
		NSData *metadataData = [metadataFileWrapper regularFileContents];
		if (metadataData) {
			NSPropertyListFormat format;
			NSDictionary *metadata = [NSPropertyListSerialization propertyListWithData:metadataData
																			   options:0
																				format:&format
																				 error:NULL];
			if (metadata) {
				// Get the resolution scale
				NSNumber *resScale = metadata[@"SelectedResolution"];
				if (resScale) {
					self.resolutionScale = resScale.intValue;
				}
			}
		}
	}
	
    return YES;
}

- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
    NSFileWrapper *contents = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{}];

    NSData *fragmentSourceData = [self.fragmentSource dataUsingEncoding:NSUTF8StringEncoding];

    NSFileWrapper *metalWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:fragmentSourceData];
    [metalWrapper setPreferredFilename:@"Shaders.metal"];
    [contents addFileWrapper:metalWrapper];

    if (self.thumbnailImage) {
        NSData *thumbnailData = UIImagePNGRepresentation(self.thumbnailImage);
        if (thumbnailData) {
            NSFileWrapper *thumbnailWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:thumbnailData];
            thumbnailWrapper.preferredFilename = @"Thumbnail@2x.png";
            [contents addFileWrapper:thumbnailWrapper];
        }
    }

     // add additional content (metadata, assets...)
	// Just the selected resolution scaling for now...
	NSDictionary *metadata = @{@"SelectedResolution": @(self.resolutionScale)};
	NSData *metadataData = [NSPropertyListSerialization dataWithPropertyList:metadata
																	 format:NSPropertyListBinaryFormat_v1_0
																	options:0
																	  error:NULL];
	NSFileWrapper *metadataWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:metadataData];
	metadataWrapper.preferredFilename = @"Metadata.plist";
	[contents addFileWrapper:metadataWrapper];
	
    return contents;
}

- (BOOL)hasUnsavedChanges {
    return self.isDirty;
}

- (void)presentedItemDidMoveToURL:(NSURL *)newURL {
    [super presentedItemDidMoveToURL:newURL];
}

- (void)saveToURL:(NSURL *)url
 forSaveOperation:(UIDocumentSaveOperation)saveOperation
completionHandler:(void (^)(BOOL))completionHandler
{
    [super saveToURL:url forSaveOperation:saveOperation completionHandler: ^(BOOL success) {
        if (success) {
            self.dirty = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:STWDocumentDidSaveNotificationName
                                                                object:self];
        }

        if (completionHandler) {
            completionHandler(success);
        }
    }];
}

- (void)setFragmentSource:(NSString *)fragmentSource {
    _fragmentSource = fragmentSource;
    self.dirty = YES;
    [self buildLibrary];
}

- (void)setThumbnailImage:(UIImage *)thumbnailImage {
    _thumbnailImage = thumbnailImage;
    self.dirty = YES;
}

-(void)setResolutionScale:(int)resolutionScale {
	_resolutionScale = resolutionScale;
	self.dirty = YES;
}

- (NSString *)patchSpecialHeadersInSource:(NSString *)source {
    NSError *error = nil;
    NSString *hgsdfInclude = @"#include <hg_sdf>";
    if ([source rangeOfString:hgsdfInclude].location != NSNotFound) {
        NSURL *hgsdfURL = [[NSBundle mainBundle] URLForResource:@"hg_sdf" withExtension:@"metal"];
        if (hgsdfURL) {
            NSString *hgsdfSource = [NSString stringWithContentsOfURL:hgsdfURL encoding:NSUTF8StringEncoding error:&error];
            if ([hgsdfSource length] > 0) {
                NSLog(@"Replacing hg_sdf include with library source");
                return [source stringByReplacingOccurrencesOfString:hgsdfInclude withString:hgsdfSource];
            } else {
                NSLog(@"Shader requested hg_sdf library, but source could not be loaded from the app bundle");
            }
        } else {
            NSLog(@"Shader requested hg_sdf library, but source was not found in the app bundle");
        }
    }
    return source;
}

- (void)buildLibrary {
    NSTimeInterval compilationStartTime = CACurrentMediaTime();
    self.lastCompilationStartTime = compilationStartTime;
    
    NSString *entireSource = [self.preambleSource stringByAppendingString:self.fragmentSource];
//    entireSource = [self patchSpecialHeadersInSource:entireSource];

    NSError *error = nil;
    id<MTLLibrary> library =
    [self.metalContext.device newLibraryWithSource:entireSource
                                           options:nil
                                             error:&error];

    // Async compilation isn't currently working, but this could be the contents of the callback block:
    {
        if (self.lastCompilationStartTime != compilationStartTime) {
            NSLog(@"Finished compilation, but it wasn't the most recently-requested compilation, so ignoring...");
            return;
        }

        self.currentLibrary = library;

        if (self.currentLibrary) {
            // ORDER MATTERS HERE since the last-known good library is KVO'able
            self.lastKnownGoodFragmentSource = self.fragmentSource;
            self.lastKnownGoodLibrary = self.currentLibrary;
            self.lastCompilationErrors = @[];
        } else {
            // WILL TRIGGER KVO
            self.lastCompilationErrors = [STWCompilerDiagnosticParser compilerMessagesForDiagnosticString:error.localizedDescription];
        }

        //        NSLog(@"Most recent compilation request took %0.1fms and completed with %@ library and %d error(s)",
        //              1000 * (CACurrentMediaTime() - self.lastCompilationStartTime), self.currentLibrary ? @"a" : @"no",
        //              (int)self.lastCompilationErrors.count);
    }
}

- (NSInteger)fragmentShaderLineNumberBias {
    return -1 * [self.preambleSource componentsSeparatedByString:@"\n"].count;
}

@end


