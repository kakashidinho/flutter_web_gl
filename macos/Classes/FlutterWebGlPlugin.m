#import "FlutterWebGlPlugin.h"
#import "MetalANGLE/EGL/egl.h"
#import "MetalANGLE/angle_gl.h"



@implementation OpenGLException

- (instancetype) initWithMessage: (NSString*) message andError: (int) error
{
    self = [super init];
    if (self){
    _message = message;
    _errorCode = error;
    }
    return self;
}

@end



@implementation FlutterGlTexture
- (instancetype)initWithWidth:(int) width andHeight:(int)height registerWidth:(NSObject<FlutterTextureRegistry>*) registry{
    self = [super init];
    if (self){
        NSDictionary* options = @{
          // This key is required to generate SKPicture with CVPixelBufferRef in metal.
          (NSString*)kCVPixelBufferMetalCompatibilityKey : @YES
        };

        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                              kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options, &_pixelData);
        if (status != 0)
        {
            NSLog(@"CVPixelBufferCreate error %d", (int)status);
        }

        _flutterTextureId = [registry registerTexture:self];

    }
    
    return self;
}


#pragma mark - FlutterTexture

- (CVPixelBufferRef)copyPixelBuffer {
    CVBufferRetain(_pixelData);
    return _pixelData;
}

@end

/*
FlutterGLTexture
{
public:
  virtual ~FlutterGLTexture();
  const FlutterDesktopPixelBuffer *CopyPixelBuffer(size_t width, size_t height);

 std::unique_ptr<FlutterDesktopPixelBuffer> buffer;
  GLuint fbo;
  GLuint rbo;
  int64_t flutterTextureId;
  std::unique_ptr<flutter::TextureVariant> flutterTexture;
private:
  std::unique_ptr<uint8_t> pixels;
  size_t request_count_ = 0;


};
*/

@interface FlutterWebGlPlugin()
@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *textureRegistry;
@property (nonatomic,strong) FlutterGlTexture* flutterGLTexture;

@end

@implementation FlutterWebGlPlugin

- (instancetype)initWithTextures:(NSObject<FlutterTextureRegistry> *)textures {
    self = [super init];
    if (self) {
        _textureRegistry = textures;
    }
    return self;
}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel =
          [FlutterMethodChannel methodChannelWithName:@"flutter_web_gl"
                                      binaryMessenger:[registrar messenger]];
    FlutterWebGlPlugin* instance = [[FlutterWebGlPlugin alloc] initWithTextures:[registrar textures]];
    [registrar addMethodCallDelegate:instance channel:channel];
    
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"initOpenGL"]) {
        static EGLContext  context;
        if (context != NULL)
        {
          // this means initOpenGL() was already called, which makes sense if you want to acess a Texture not only
          // from the main thread but also from an isolate. On the plugin layer here that doesn't bother because all
          // by `initOpenGL``in Dart created contexts will be linked to the one we got from the very first call to `initOpenGL`
          // we return this information so that the Dart side can dispose of one context.

            result([NSNumber numberWithLong: (long)context]);
          return;
          
        }
        // Obtain the OpenGL context that was created on the Dart side
        // it is linked to the context that is used by the Dart side for all further OpenGL operations over FFI
        // Because of that they are shared (linked) they have both access to the same RenderbufferObjects (RBO) which allows
        // The Dart main thread to render into an Texture RBO which can then accessed from this thread and passed to the Flutter Engine
        if (call.arguments) {
            NSNumber* contextAsNSNumber = call.arguments[@"openGLContext"];
            context = (EGLContext) contextAsNSNumber.longValue;
        }
        else
        {
          result([FlutterError errorWithCode: @"No OpenGL context" message: @"No OpenGL context received by the native part of FlutterGL.iniOpenGL"  details:NULL]);
          return;
        }

        EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        EGLint major;
        EGLint minor;
        int initializeResult = eglInitialize(display,&major,&minor);
        if (initializeResult != 1)
        {
            result([FlutterError errorWithCode: @"No OpenGL context" message: @"eglInit failed"  details:NULL]);
            return;
        }
        
        const EGLint attribute_list[] = {
          EGL_RED_SIZE, 8,
          EGL_GREEN_SIZE, 8,
          EGL_BLUE_SIZE, 8,
          EGL_ALPHA_SIZE, 8,
          EGL_DEPTH_SIZE, 16,
          EGL_NONE};

        EGLint num_config;
        EGLConfig config;
        EGLBoolean chooseConfigResult = eglChooseConfig(display,attribute_list,&config,1,&num_config);
        if (chooseConfigResult != 1)
        {
            result([FlutterError errorWithCode: @"EGL InitError" message: @"Failed to call eglCreateWindowSurface()"  details:NULL]);
            return;
        }


        // This is just a dummy surface that it needed to make an OpenGL context current (bind it to this thread)
        CALayer* dummyLayer       = [[CALayer alloc] init];
        dummyLayer.frame = CGRectMake(0, 0, 1, 1);
        CALayer* dummyLayer2       = [[CALayer alloc] init];
        dummyLayer2.frame = CGRectMake(0, 0, 1, 1);

        EGLSurface dummySurfaceForDartSide = eglCreateWindowSurface(display, config,(__bridge EGLNativeWindowType)dummyLayer, NULL);
        EGLSurface dummySurface = eglCreateWindowSurface(display,
            config,(__bridge EGLNativeWindowType)dummyLayer2, NULL);
        
        if ((dummySurfaceForDartSide == EGL_NO_SURFACE) || (dummySurface == EGL_NO_SURFACE))
        {
            result([FlutterError errorWithCode: @"EGL InitError" message: @"Dummy Surface creation failed"  details:NULL]);
            return;

        }
        if (eglMakeCurrent(display, dummySurface, dummySurface, context)!=1)
        {
            NSLog(@"MakeCurrent failed: %d",eglGetError());
        }

        char* v = (char*) glGetString(GL_VENDOR);
        int error = glGetError();
        if (error != GL_NO_ERROR)
        {
            NSLog(@"GLError: %d",error);
        }
        char* r = (char*) glGetString(GL_RENDERER);
        char* v2 = (char*) glGetString(GL_VERSION);

        if (v==NULL)
        {
            NSLog(@"GetString: GL_VENDOR returned NULL");
        }
        if (r==NULL)
        {
            NSLog(@"GetString: GL_RENDERER returned NULL");
        }
        if (v2==NULL)
        {
            NSLog(@"GetString: GL_VERSION returned NULL");
        }
       NSLog(@"%@\n%@\n%@\n",[[NSString alloc] initWithUTF8String: v],[[NSString alloc] initWithUTF8String: r],[[NSString alloc] initWithUTF8String: v2]);
        /// we send back the context. This might look a bit strange, but is necessary to allow this function to be called
        /// from Dart Isolates.
        result(@{@"context" : [NSNumber numberWithLong: (long)context],
                 @"dummySurface" : [NSNumber numberWithLong: (long)dummySurfaceForDartSide]
               });
        return;
        
    }
    if ([call.method isEqualToString:@"createTexture"]) {
        NSNumber* width;
        NSNumber* height;
        if (call.arguments) {
            width = call.arguments[@"width"];
            if (width == NULL)
            {
                result([FlutterError errorWithCode: @"CreateTexture Error" message: @"No width received by the native part of FlutterGL.createTexture"  details:NULL]);
                return;

            }
            height = call.arguments[@"height"];
            if (height == NULL)
            {
                result([FlutterError errorWithCode: @"CreateTexture Error" message: @"No height received by the native part of FlutterGL.createTexture"  details:NULL]);
                return;

            }
        }
        else
        {
          result([FlutterError errorWithCode: @"No arguments" message: @"No arguments received by the native part of FlutterGL.createTexture"  details:NULL]);
          return;
        }

        
        

        @try
        {
            _flutterGLTexture = [[FlutterGlTexture alloc] initWithWidth:640 andHeight:320 registerWidth:_textureRegistry];
        }
        @catch (OpenGLException* ex)
        {
            result([FlutterError errorWithCode: [@( [ex errorCode]) stringValue]
                                       message: [@"Error creating FlutterGLTextureObjec: " stringByAppendingString:[ex message]] details:NULL]);
            return;
        }

//        flutterGLTextures.insert(TextureMap::value_type(flutterGLTexture->flutterTextureId, std::move(flutterGLTexture)));
        result(@{
           @"textureId" : [NSNumber numberWithLongLong: [_flutterGLTexture flutterTextureId]],
           @"rbo": [NSNumber numberWithLongLong: [_flutterGLTexture  rbo]]
        });

        return;
    }
        if ([call.method isEqualToString:@"getAll"]) {
        result(@{
          @"appName" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
              ?: [NSNull null],
          @"packageName" : [[NSBundle mainBundle] bundleIdentifier] ?: [NSNull null],
          @"version" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
              ?: [NSNull null],
          @"buildNumber" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
              ?: [NSNull null],
        });
} else {
    result(FlutterMethodNotImplemented);
  }
}
@end
