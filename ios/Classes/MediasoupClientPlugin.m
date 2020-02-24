#import "MediasoupClientPlugin.h"
#if __has_include(<mediasoup_client/mediasoup_client-Swift.h>)
#import <mediasoup_client/mediasoup_client-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "mediasoup_client-Swift.h"
#endif

@implementation MediasoupClientPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftMediasoupClientPlugin registerWithRegistrar:registrar];
}
@end
