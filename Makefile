TARGET = iphone:clang:13.7:11.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCSupport
CCSupport_CFLAGS = -fobjc-arc -DTHEOS_LEAN_AND_MEAN
CCSupport_LOGOS_DEFAULT_GENERATOR = internal
CCSupport_FILES = $(wildcard *.xm)
CCSupport_PRIVATE_FRAMEWORKS = MobileIcons Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

#SUBPROJECTS += HomeProvider
#include $(THEOS_MAKE_PATH)/aggregate.mk
