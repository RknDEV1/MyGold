TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyGoldAPI

MyGoldAPI_FILES = MyGoldAPI.mm entry.mm
MyGoldAPI_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MyGoldAPI_LDFLAGS = -fuse-ld=lld
MyGoldAPI_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore Security
MyGoldAPI_LIBRARIES = z sqlite3

_THEOS_NO_STRIP = 1

include $(THEOS_MAKE_PATH)/tweak.mk
