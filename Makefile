export TARGET = iphone:clang:11.2:11.0
export ARCHS = arm64

export ROOTLESS ?= 0;

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCSupport
CCSupport_CFLAGS = -fobjc-arc
ifeq ($(ROOTLESS), 1)
	CCSupport_CFLAGS += -fobjc-arc -D ROOTLESS=1
endif
CCSupport_FILES = Tweak.xm
CCSupport_PRIVATE_FRAMEWORKS = MobileIcons Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

include $(THEOS_MAKE_PATH)/aggregate.mk
