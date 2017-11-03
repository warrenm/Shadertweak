@import UIKit;

@class STWEditableLabel;

@protocol STWEditableLabelDelegate <NSObject>
@optional
- (void)editableLabel:(STWEditableLabel *)label textDidChange:(NSString *)text;
- (void)editableLabelDidEndEditing:(STWEditableLabel *)label;
@end

@interface STWEditableLabel : UIView

@property (nonatomic, copy) NSString *text;
@property (nonatomic, weak) id<STWEditableLabelDelegate> delegate;

@end
