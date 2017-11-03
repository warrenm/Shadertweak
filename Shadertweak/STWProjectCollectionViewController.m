#import "STWProjectCollectionViewController.h"
#import "STWProjectViewController.h"
#import "STWDocument.h"
#import "STWProjectCell.h"

@interface STWProjectCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *projectCollectionView;
@property (nonatomic, strong) NSURL *documentsURL;
@property (nonatomic, strong) NSArray<NSURL *> *projectURLs;
@end

@implementation STWProjectCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Projects";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addNew:)];

    self.documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask] firstObject];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentDidSave:)
                                                 name:STWDocumentDidSaveNotificationName
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:STWDocumentDidSaveNotificationName
                                                  object:nil];
}

- (void)loadView {
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.minimumLineSpacing = 44;
    flowLayout.minimumInteritemSpacing = 30;
    flowLayout.itemSize = CGSizeMake(256, 192);
    flowLayout.sectionInset = UIEdgeInsetsMake(44, 44, 44, 44);

    self.projectCollectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 320, 320)
                                                    collectionViewLayout:flowLayout];
    self.projectCollectionView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.view = self.projectCollectionView;

    [self.projectCollectionView registerClass:[STWProjectCell class] forCellWithReuseIdentifier:@"ProjectCell"];
    self.projectCollectionView.dataSource = self;
    self.projectCollectionView.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    NSError *error = nil;
    self.projectURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.documentsURL
                                                     includingPropertiesForKeys:@[]
                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                          error:&error];

    [self.projectCollectionView reloadData];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (STWDocument *)generateDocument {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSDate *now = [NSDate date];
    NSString *documentTitle = [dateFormatter stringFromDate:now];

    NSURL *documentURL = [[self.documentsURL URLByAppendingPathComponent:documentTitle]
                          URLByAppendingPathExtension:@"stweak"];

    STWDocument *document = [[STWDocument alloc] initWithFileURL:documentURL];

    [document saveToURL:documentURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
        NSLog(@"Saved newly created document at %@", documentURL);
    }];

    return document;
}

- (void)presentEditorWithDocument:(STWDocument *)document {
    STWProjectViewController *splitViewController = [[STWProjectViewController alloc] initWithNibName:nil bundle:nil];
    
    [document openWithCompletionHandler:^(BOOL success) {
        splitViewController.document = document;
    }];
    
    [self.navigationController pushViewController:splitViewController animated:YES];
}

#pragma mark - Actions

- (void)addNew:(id)sender {
    STWDocument *document = [self generateDocument];
    [self presentEditorWithDocument:document];
}

- (void)reloadProjects {
    self.documentsURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                inDomains:NSUserDomainMask] firstObject];

    [self.projectCollectionView reloadData];
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSURL *projectURL = self.projectURLs[indexPath.item];
    STWDocument *document = [[STWDocument alloc] initWithFileURL:projectURL];
    [self presentEditorWithDocument:document];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.projectURLs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    STWProjectCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ProjectCell" forIndexPath:indexPath];
    [cell setBackgroundColor:[UIColor colorWithWhite:0.08 alpha:1.0]];
    cell.imageView.image = [UIImage imageNamed:@"ProjectThumbnail"];
    cell.label.text = [[self.projectURLs[indexPath.item] lastPathComponent] stringByDeletingPathExtension];

    // TODO: This is grossly synchronous. Should fix that.
    NSURL *thumbnailURL = [self.projectURLs[indexPath.item] URLByAppendingPathComponent:@"Thumbnail@2x.png"];
    NSData *thumbnailData = [NSData dataWithContentsOfURL:thumbnailURL];
    if (thumbnailData) {
        UIImage *projectThumbnail = [UIImage imageWithData:thumbnailData scale:2.0];
        if (projectThumbnail) {
            cell.imageView.image = projectThumbnail;
        }
    }

    return cell;
}

#pragma mark - Notifications

- (void)documentDidSave:(NSNotification *)notification {
    STWDocument *document = [notification object];
    if (document) {
        NSInteger itemIndex = [self.projectURLs indexOfObject:document.fileURL];
        if (itemIndex != NSNotFound) {
            NSIndexPath *projectIndexPath = [NSIndexPath indexPathForItem:itemIndex inSection:0];
            NSLog(@"Reloading cell for item at %@", projectIndexPath);
            [self.projectCollectionView reloadItemsAtIndexPaths:@[projectIndexPath]];
            return;
        }
    }

    NSLog(@"Did not have the document that was just saved in project URL cache. Indiscriminately reloading...");
    [self reloadProjects];
}

@end
