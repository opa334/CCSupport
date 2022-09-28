export TARGET = iphone:clang:13.7:11.0
export ARCHS = arm64 arm64e

export ROOTLESS ?= 0

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCSupport
CCSupport_CFLAGS = -fobjc-arc
ifeq ($(ROOTLESS), 1)
	CCSupport_CFLAGS += -D ROOTLESS=1
endif
CCSupport_FILES = $(wildcard *.xm *.m)
CCSupport_PRIVATE_FRAMEWORKS = MobileIcons Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += HomeProvider
include $(THEOS_MAKE_PATH)/aggregate.mk
