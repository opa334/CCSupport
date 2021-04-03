export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/
export TARGET = iphone:clang:13.0:11.0
export ARCHS = arm64 arm64e

export ROOTLESS ?= 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CCSupport
CCSupport_CFLAGS = -fobjc-arc
ifeq ($(ROOTLESS), 1)
	CCSupport_CFLAGS += -D ROOTLESS=1
endif
CCSupport_FILES = Tweak.xm
CCSupport_PRIVATE_FRAMEWORKS = MobileIcons Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

include $(THEOS_MAKE_PATH)/aggregate.mk
