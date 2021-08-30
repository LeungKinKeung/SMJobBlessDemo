//
//  ViewController.h
//  SMJobBlessDemo
//
//  Created by leungkinkeung on 2021/8/20.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextField *textField;
@property (weak) IBOutlet NSButton *executeButton;
@property (weak) IBOutlet NSButton *quitButton;
@property (weak) IBOutlet NSButton *uninstallButton;
- (IBAction)executeButtonClicked:(id)sender;
- (IBAction)quitButtonClicked:(id)sender;
- (IBAction)uninstallButtonClicked:(id)sender;


@end

