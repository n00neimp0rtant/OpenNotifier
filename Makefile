include theos/makefiles/common.mk

TWEAK_NAME = OpenNotifier
OpenNotifier_FILES = Tweak.xm
OpenNotifier_LDFLAGS = -L./ -lstatusbar

include $(THEOS_MAKE_PATH)/tweak.mk
