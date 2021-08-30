//
//  CommandHelper.m
//  com.ljq.SMJobBlessApp.CommandHelper
//
//  Created by leungkinkeung on 2021/8/20.
//

#import "CommandHelper.h"

@interface CommandHelper () <NSXPCListenerDelegate>

@property (nonatomic, strong) NSXPCListener *listener;

@end

@implementation CommandHelper

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.listener           = [[NSXPCListener alloc] initWithMachServiceName:HELPER_MACH_SERVICE_NAME];
        self.listener.delegate  = self;
    }
    return self;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(CommandHelperProtocol)];
    newConnection.exportedObject    = self;
    [newConnection resume];
    return YES;
}

- (void)executeCommand:(NSString *)command reply:(nonnull void (^)(int))reply
{
    reply(system(command.UTF8String));
}

- (void)run
{
    [self.listener resume];
    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] run];
}

- (void)quit
{
    exit(0);
}

@end
