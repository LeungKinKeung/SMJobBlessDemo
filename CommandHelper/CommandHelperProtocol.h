//
//  CommandHelperProtocol.h
//  SMJobBlessDemo
//
//  Created by leungkinkeung on 2021/8/20.
//

#import <Foundation/Foundation.h>

#define HELPER_MACH_SERVICE_NAME @"com.ljq.SMJobBlessApp.CommandHelper"

@protocol CommandHelperProtocol

- (void)executeCommand:(NSString *)command reply:(void(^)(int result))reply;

- (void)quit;

@end
