XINA_SUPPORT ?= 0

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET := iphone:clang:16.2:15.0
else
TARGET := iphone:clang:14.5:11.0
endif

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCSupport
CCSupport_CFLAGS = -fobjc-arc
CCSupport_FILES = $(wildcard *.xm *.m)
CCSupport_PRIVATE_FRAMEWORKS = MobileIcons Preferences

ifeq ($(XINA_SUPPORT),1)
CCSupport_CFLAGS += -D XINA_SUPPORT=1
endif

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += HomeProvider
include $(THEOS_MAKE_PATH)/aggregate.mk
