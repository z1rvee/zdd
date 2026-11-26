#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <dlfcn.h>

extern "C" {
    typedef struct lua_State lua_State;
    typedef int (*luaL_loadstring_t)(lua_State *L, const char *s);
    typedef int (*lua_pcall_t)(lua_State *L, int nargs, int nresults, int msgh);
}

static lua_State *g_activeLuaState = NULL;

static void run_lua_buffer(lua_State *L, const char *script) {
    if (!L || !script || script[0] == '\0') return;

    auto p_loadstring = (luaL_loadstring_t)dlsym(RTLD_DEFAULT, "luaL_loadstring");
    auto p_pcall = (lua_pcall_t)dlsym(RTLD_DEFAULT, "lua_pcall");
    if (!p_loadstring || !p_pcall) return;

    if (p_loadstring(L, script) == 0) {
        p_pcall(L, 0, 0, 0);
    }
}

@interface LuaFilePickerHandler : NSObject <UIDocumentPickerDelegate>
+ (instancetype)shared;
- (void)presentLuaPicker;
@end

@implementation LuaFilePickerHandler

+ (instancetype)shared {
    static LuaFilePickerHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LuaFilePickerHandler alloc] init];
    });
    return instance;
}

- (UIViewController *)topPresenter {
    UIViewController *root = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *winScene = (UIWindowScene *)scene;
            for (UIWindow *win in winScene.windows) {
                if (win.isKeyWindow) {
                    root = win.rootViewController;
                    break;
                }
            }
            if (!root && winScene.windows.count > 0) {
                root = winScene.windows.firstObject.rootViewController;
            }
            break;
        }
    }

    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

- (void)presentLuaPicker {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = [self topPresenter];
        if (!presenter) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self presentLuaPicker];
            });
            return;
        }

        UTType *luaType = [UTType typeWithIdentifier:@"public.lua-script"];
        if (!luaType) {
            luaType = [UTType typeWithFilenameExtension:@"lua" conformingToType:UTTypePlainText];
        }
        if (!luaType) {
            luaType = UTTypePlainText;
        }

        UIDocumentPickerViewController *picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[luaType] asCopy:YES];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        [presenter presentViewController:picker animated:YES completion:nil];
    });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *fileURL = urls.firstObject;
    if (!fileURL) return;

    if (![[fileURL.pathExtension lowercaseString] isEqualToString:@"lua"]) {
        return;
    }

    BOOL accessed = [fileURL startAccessingSecurityScopedResource];
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&err];
    if (accessed) {
        [fileURL stopAccessingSecurityScopedResource];
    }

    if (!content || err) return;

    const char *luaCode = [content UTF8String];
    if (g_activeLuaState && luaCode) {
        run_lua_buffer(g_activeLuaState, luaCode);
    }
}

@end

__attribute__((constructor))
static void on_dylib_load(void) {
    [[LuaFilePickerHandler shared] presentLuaPicker];
}
