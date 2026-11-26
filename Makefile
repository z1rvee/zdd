TARGET := iphone:clang:latest:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LuaRunner
LuaRunner_FILES = Tweak.mm
LuaRunner_CFLAGS = -fobjc-arc
LuaRunner_FRAMEWORKS = UIKit UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk
