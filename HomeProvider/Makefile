ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET := iphone:clang:16.2:15.0
else
TARGET := iphone:clang:14.5:11.0
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HomeProvider
HomeProvider_BUNDLE_EXTENSION = bundle
HomeProvider_FILES = $(wildcard *.x *.m)
HomeProvider_CFLAGS = -fobjc-arc
HomeProvider_PRIVATE_FRAMEWORKS = ControlCenterUIKit Preferences
HomeProvider_INSTALL_PATH = /Library/ControlCenter/CCSupport_Providers/

include $(THEOS_MAKE_PATH)/bundle.mk
