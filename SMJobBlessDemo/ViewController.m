//
//  ViewController.m
//  SMJobBlessDemo
//
//  Created by leungkinkeung on 2021/8/20.
//

#import "ViewController.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>
#import "CommandHelperProtocol.h"

@interface ViewController (){
    AuthorizationRef _authRef;
}
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initHelper];
}

- (void)initHelper
{
    BOOL isAvailable    = YES;
    NSError *error      = nil;
    
    do {
        NSString *installedPath = [NSString stringWithFormat:@"/Library/PrivilegedHelperTools/%@", HELPER_MACH_SERVICE_NAME];
        // 判断是否已存在
        if ([[NSFileManager defaultManager] fileExistsAtPath:installedPath]) {
            // 判断版本是否一致
            NSDictionary *installedInfo =
            CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((__bridge CFURLRef)[NSURL fileURLWithPath:installedPath]));
            NSString *installedVersion  = [installedInfo objectForKey:(NSString *)kCFBundleVersionKey];
            
            NSURL *url = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:
                          [NSString stringWithFormat:@"Contents/Library/LaunchServices/%@", HELPER_MACH_SERVICE_NAME]];
            NSDictionary *info = CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((__bridge CFURLRef)url));
            NSString *version  = [info objectForKey:(NSString *)kCFBundleVersionKey];
            if ([version isEqualToString:installedVersion]) {
                break;
            }
            // 重新安装
        }
        OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &self->_authRef);
        if (status != errAuthorizationSuccess) {
            /* AuthorizationCreate really shouldn't fail. */
            assert(NO);
            self->_authRef = NULL;
        }
        isAvailable = [self blessHelperWithLabel:HELPER_MACH_SERVICE_NAME error:&error];
    } while (NO);
    
    if (isAvailable) {
        self.executeButton.hidden           = NO;
        self.quitButton.hidden              = NO;
        self.uninstallButton.hidden         = NO;
        self.textField.placeholderString    = @"Command";
        self.textField.stringValue          = @"networksetup -setdnsservers Wi-Fi 8.8.8.8";
        // 还原DNS:"networksetup -setdnsservers Wi-Fi Empty"
    } else {
        self.textField.editable     = NO;
        self.textField.bordered     = NO;
        self.textField.stringValue  =
        [NSString stringWithFormat:@"Something went wrong! code:%ld %@",error.code,error.localizedDescription];
    }
}

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)errorPtr
{
    BOOL result     = NO;
    NSError * error = nil;
    
    AuthorizationItem authItem      = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights  = { 1, &authItem };
    AuthorizationFlags flags        =   kAuthorizationFlagDefaults              |
                                        kAuthorizationFlagInteractionAllowed    |
                                        kAuthorizationFlagPreAuthorize          |
                                        kAuthorizationFlagExtendRights;
                                               
    /* Obtain the right to install our privileged helper tool (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCopyRights(self->_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
        NSString *errMsg = (__bridge_transfer NSString *)SecCopyErrorMessageString(status, NULL);
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:@{NSLocalizedDescriptionKey:errMsg}];
    } else {
        CFErrorRef  cfError;
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        // 假如成功，Helper-Launchd.plist将复制到/Library/LaunchDaemons目录下并命名为'com.ljq.SMJobBlessApp.CommandHelper'
        // 可执行文件'com.ljq.SMJobBlessApp.CommandHelper'将复制到/Library/PrivilegedHelperTools目录下
        result = (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, self->_authRef, &cfError);
        if (!result) {
            error = CFBridgingRelease(cfError);
        }
    }
    if (!result && (errorPtr != NULL) ) {
        assert(error != nil);
        *errorPtr = error;
    }
    return result;
}

- (void)executeCommand:(NSString *)command reply:(void(^)(int result))reply
{
    NSXPCConnection *xpcConnection      = [[NSXPCConnection alloc] initWithMachServiceName:HELPER_MACH_SERVICE_NAME
                                                                                   options:NSXPCConnectionPrivileged];
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(CommandHelperProtocol)];
    xpcConnection.exportedInterface     = [NSXPCInterface interfaceWithProtocol:@protocol(CommandHelperProtocol)];
    xpcConnection.exportedObject        = self;
    [[xpcConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        // 无法连接XPC服务、Helper进程已退出或已崩溃
        NSLog(@"Get remote object proxy error: %@",error);
        reply((int)error.code);
    }] executeCommand:command reply:reply];
    [xpcConnection resume];
}

- (IBAction)executeButtonClicked:(id)sender
{
    [self executeCommand:self.textField.stringValue reply:^(int result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert          = [NSAlert new];
            alert.informativeText   =
            result == errSecSuccess ? @"Execute succeeded" : [NSString stringWithFormat:@"Execute failed: %d",result];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        });
    }];
}

- (IBAction)quitButtonClicked:(id)sender
{
    NSXPCConnection *xpcConnection      = [[NSXPCConnection alloc] initWithMachServiceName:HELPER_MACH_SERVICE_NAME
                                                                                   options:NSXPCConnectionPrivileged];
    xpcConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(CommandHelperProtocol)];
    xpcConnection.exportedInterface     = [NSXPCInterface interfaceWithProtocol:@protocol(CommandHelperProtocol)];
    xpcConnection.exportedObject        = self;
    [[xpcConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Get remote object proxy failed: %@",error);
    }] quit];
    [xpcConnection resume];
}

- (IBAction)uninstallButtonClicked:(id)sender
{
    NSString *scriptPath    = [[NSBundle mainBundle] pathForResource:@"Uninstall" ofType:@"sh"];
    if (scriptPath == nil) {
        NSAlert *alert      = [NSAlert new];
        alert.messageText   = @"'Uninstall.sh' file not found!!!";
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        return;
    }
    NSString *shellScript   = [NSString stringWithFormat:@"out=`sh \\\"%@\\\"`",scriptPath];
    NSString *script        = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", shellScript];

    NSDictionary *errorInfo         = nil;
    NSAppleScript *appleScript      = [[NSAppleScript new] initWithSource:script];
    NSAppleEventDescriptor *result  = [appleScript executeAndReturnError:&errorInfo];
    if(!result) {
        NSLog(@"Execute script result:%@", [result stringValue]);
    }
    NSAlert *alert              = [NSAlert new];
    if (errorInfo == nil || errorInfo.count == 0) {
        alert.messageText       = @"Uninstall succeeded!!!";
    } else {
        alert.messageText       = @"Uninstall failed!!!";
        alert.informativeText   = errorInfo.description;
    }
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

@end
