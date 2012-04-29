.PHONY: before-release after-release release debugrelease

DEBUG = 1
DEBUGFLAG = -ggdb
GO_EASY_ON_ME = 1
TARGET = iphone:latest:3.2
THEOS_BUILD_DIR = build
ADDITIONAL_CFLAGS = -Iinclude
ADDITIONAL_LDFLAGS = -L./lib 

TWEAK_NAME = OpenNotifier
OpenNotifier_FILES = Tweak.xm Preferences.mm

BUNDLE_NAME = OpenNotifierSettings
OpenNotifierSettings_BUNDLE_NAME = OpenNotifier
OpenNotifierSettings_FILES =  Settings.mm Preferences.mm
OpenNotifierSettings_INSTALL_PATH = /Library/PreferenceBundles
OpenNotifierSettings_FRAMEWORKS = UIKit CoreGraphics
OpenNotifierSettings_PRIVATE_FRAMEWORKS = Preferences
OpenNotifierSettings_LIBRARIES = applist substrate

ifeq ($(DEBUGPREFS),1)
DEBUGFLAG += -DDEBUGPREFS
endif

include theos/makefiles/common.mk
# THEOS_STAGING_DIR is here because of a bug 
# theos needs to be fixed at some point
THEOS_STAGING_DIR = build/stage
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

clean:: 
	rm -rf $(THEOS_BUILD_DIR)/*.deb
	rm -f ./*.deb
	
ifneq ($(THEOS_DEVICE_IP),)
	@install.exec "rm -rf com.n00neimp0rtant.opennotifier_*.deb"
endif	
	
release::
	@$(MAKE) clean before-release DEBUG="" MAKELEVEL=0 THEOS_SCHEMA="" SCHEMA="release" GO_EASY_ON_ME=0

beta::
	@$(MAKE) clean before-release MAKELEVEL=0 GO_EASY_ON_ME=0 PACKAGE_NAME="beta"
	
before-release:: all		
	@$(EDITOR) layout/DEBIAN/control
	@$(MAKE) after-release

after-release:: FINAL_CONTROL_FILE = "$(THEOS_STAGING_DIR)/DEBIAN/control"
after-release:: stage	
	@rm -rf $(THEOS_PROJECT_DIR)/.theos/packages
	@echo "Making Package $(THEOS_PACKAGE_NAME) Version: $(THEOS_PACKAGE_BASE_VERSION)"
	$(ECHO_NOTHING)rsync -a "$(THEOS_PROJECT_DIR)/layout/DEBIAN" "$(THEOS_STAGING_DIR)"$(ECHO_END)
	$(ECHO_NOTHING)echo "Installed-Size: $(shell du $(_THEOS_PLATFORM_DU_EXCLUDE) DEBIAN -ks "$(THEOS_STAGING_DIR)" | cut -f 1)" >> $(FINAL_CONTROL_FILE)$(ECHO_END)
	@$(FAKEROOT) -r dpkg-deb -b $(THEOS_STAGING_DIR) "$(THEOS_BUILD_DIR)/$(THEOS_PACKAGE_NAME)_$(THEOS_PACKAGE_BASE_VERSION)$(if $(PACKAGE_BUILDNAME),"+"$(PACKAGE_BUILDNAME))_$(THEOS_PACKAGE_ARCH).deb" > /dev/null 2>&1	

after-release::	
#following is used incase someone does a make release install
_THEOS_PACKAGE_LAST_VERSION = $(THEOS_PACKAGE_BASE_VERSION)