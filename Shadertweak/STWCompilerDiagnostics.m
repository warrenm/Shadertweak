
#import "STWCompilerDiagnostics.h"

@implementation STWCompilerMessage

- (instancetype)initWithMessage:(NSString *)message
                       severity:(STWCompilerMessageSeverity)severity
                     lineNumber:(NSInteger)lineNumber
                   columnNumber:(NSInteger)columnNumber
{
    if ((self = [super init])) {
        _message = [message copy];
        _severity = severity;
        _lineNumber = lineNumber;
        _columnNumber = columnNumber;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ @ %d,%d (severity: %d)",
            self.message, (int)self.lineNumber, (int)self.columnNumber, (int)self.severity];
}

@end

@implementation STWCompilerDiagnosticParser

+ (STWCompilerMessageSeverity)severityValueForSeverityString:(NSString *)severityString {
    STWCompilerMessageSeverity severity = STWCompilerMessageSeverityUnknown;
    if ([severityString isEqualToString:@"fatal error"]) {
        severity = STWCompilerMessageSeverityFatalError;
    } else if ([severityString isEqualToString:@"error"]) {
        severity = STWCompilerMessageSeverityError;
    } else if ([severityString isEqualToString:@"warning"]) {
        severity = STWCompilerMessageSeverityWarning;
    } else if ([severityString isEqualToString:@"note"]) {
        severity = STWCompilerMessageSeverityNote;
    }

    if (severity == STWCompilerMessageSeverityUnknown) {
        NSLog(@"Didn't understand severity string \"%@\"", severityString);
    }

    return severity;
}

+ (NSArray *)compilerMessagesForDiagnosticString:(NSString *)result {
    NSArray *lines = [result componentsSeparatedByString:@"\n"];

    NSPredicate *messagePredicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *, id> *bindings)
                                     {
                                         return [evaluatedObject hasPrefix:@"program_source"];
                                     }];
    NSArray *messageStrings = [lines filteredArrayUsingPredicate:messagePredicate];

    NSMutableArray *messages = [NSMutableArray array];
    [messageStrings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
        NSArray *components = [obj componentsSeparatedByString:@":"];
        if ([components count] < 5) {
            return;
        }
        NSInteger lineNumber = [components[1] integerValue];
        NSInteger columnNumber = [components[2] integerValue];
        NSString *severityString = [components[3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        STWCompilerMessageSeverity severity = [self severityValueForSeverityString:severityString];
        NSString *description = [components[4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        STWCompilerMessage *message = [[STWCompilerMessage alloc] initWithMessage:description
                                                                         severity:severity
                                                                       lineNumber:lineNumber
                                                                     columnNumber:columnNumber];
        [messages addObject:message];
    }];

    return [messages copy];
}

@end
