@import Foundation;

typedef NS_ENUM(NSInteger, STWCompilerMessageSeverity) {
    STWCompilerMessageSeverityUnknown = -1,
    STWCompilerMessageSeverityNote,
    STWCompilerMessageSeverityWarning,
    STWCompilerMessageSeverityError,
    STWCompilerMessageSeverityFatalError,
};

@interface STWCompilerMessage : NSObject
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) STWCompilerMessageSeverity severity;
@property (nonatomic, assign) NSInteger lineNumber;
@property (nonatomic, assign) NSInteger columnNumber;

- (instancetype)initWithMessage:(NSString *)message
                       severity:(STWCompilerMessageSeverity)severity
                     lineNumber:(NSInteger)lineNumber
                   columnNumber:(NSInteger)columnNumber;

@end

@interface STWCompilerDiagnosticParser : NSObject

+ (NSArray *)compilerMessagesForDiagnosticString:(NSString *)result;

@end
