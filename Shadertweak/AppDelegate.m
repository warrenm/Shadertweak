
#import "AppDelegate.h"
#import "STWProjectCollectionViewController.h"

@implementation AppDelegate

- (void)makeInterface {
    UIViewController *collectionViewController = [[STWProjectCollectionViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:collectionViewController];
    self.window.rootViewController = navigationController;

    self.window.tintColor = [UIColor colorWithRed:215/255.0 green:0/255.0 blue:143/255.0 alpha:1.0];

    UIColor *barColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    [[UINavigationBar appearance] setBarTintColor:barColor];
    [[UINavigationBar appearance] setTranslucent:NO];

    navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    [[UIToolbar appearance] setBarTintColor:barColor];
    [[UIToolbar appearance] setTranslucent:NO];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self makeInterface];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

@end
