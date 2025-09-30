//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<integration_test/IntegrationTestPlugin.h>)
#import <integration_test/IntegrationTestPlugin.h>
#else
@import integration_test;
#endif

#if __has_include(<speaker_mode/SpeakerModePlugin.h>)
#import <speaker_mode/SpeakerModePlugin.h>
#else
@import speaker_mode;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [IntegrationTestPlugin registerWithRegistrar:[registry registrarForPlugin:@"IntegrationTestPlugin"]];
  [SpeakerModePlugin registerWithRegistrar:[registry registrarForPlugin:@"SpeakerModePlugin"]];
}

@end
