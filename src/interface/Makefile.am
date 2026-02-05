SUBDIRS = resources .
#########################################################################
# APPLICATION SECTION
#########################################################################
# this is the program that gets installed.  it's name is used for all
# of the other Makefile.am variables

AUTOMAKE_OPTIONS = subdir-objects

bin_PROGRAMS = tabftp

tabftp_DEPENDENCIES =

if MACAPPBUNDLE
noinst_LIBRARIES = libfzmac.a
libfzmac_a_CPPFLAGS = $(LIBFILEZILLA_CFLAGS)
libfzmac_a_OBJCXXFLAGS = -std=c++17
libfzmac_a_CPPFLAGS += $(WX_CPPFLAGS)
tabftp_DEPENDENCIES += libfzmac.a

libfzmac_a_SOURCES = \
	dropsource_mac.mm \
	power_management_osx.mm \
	toolbar.mm
endif

# the application source, library search path, and link libraries
tabftp_SOURCES = \
		aboutdialog.cpp \
		asksavepassworddialog.cpp \
		asyncrequestqueue.cpp \
		aui_notebook_ex.cpp \
		bookmarks_dialog.cpp \
		buildinfo.cpp \
		chmoddialog.cpp \
		clearprivatedata.cpp \
		cmdline.cpp \
		commandqueue.cpp \
		conditionaldialog.cpp \
		context_control.cpp \
		customheightlistctrl.cpp \
		defaultfileexistsdlg.cpp \
		dialogex.cpp \
		dndobjects.cpp \
		dragdropmanager.cpp \
		dropsource.cpp \
		drop_target_ex.cpp \
		edithandler.cpp \
		encoding_converter.cpp \
		export.cpp \
		fileexistsdlg.cpp \
		filelistctrl.cpp \
		filelist_statusbar.cpp \
		FileZilla.cpp \
		filter_manager.cpp \
		filter_conditions_dialog.cpp \
		filteredit.cpp \
		file_utils.cpp \
		fzputtygen_interface.cpp \
		graphics.cpp \
		import.cpp \
		infotext.cpp \
		inputdialog.cpp \
		led.cpp \
		listctrlex.cpp \
		listingcomparison.cpp \
		list_search_panel.cpp \
		local_recursive_operation.cpp \
		locale_initializer.cpp \
		LocalListView.cpp \
		LocalTreeView.cpp \
		loginmanager.cpp \
		Mainfrm.cpp \
		manual_transfer.cpp \
		menu_bar.cpp \
		msgbox.cpp \
		netconfwizard.cpp \
		Options.cpp \
		option_change_event_handler.cpp \
		overlay.cpp \
		power_management.cpp \
		queue.cpp \
		queue_storage.cpp \
		QueueView.cpp \
		queueview_failed.cpp \
		queueview_successful.cpp \
		quickconnectbar.cpp \
		recentserverlist.cpp \
		recursive_operation_status.cpp \
		remote_recursive_operation.cpp \
		RemoteListView.cpp \
		RemoteTreeView.cpp \
		renderer.cpp \
		search.cpp \
		serverdata.cpp \
		settings/optionspage.cpp \
		settings/optionspage_connection.cpp \
		settings/optionspage_dateformatting.cpp \
		settings/optionspage_debug.cpp \
		settings/optionspage_edit.cpp \
		settings/optionspage_edit_associations.cpp \
		settings/optionspage_fileexists.cpp \
		settings/optionspage_filelists.cpp \
		settings/optionspage_interface.cpp \
		settings/optionspage_language.cpp \
		settings/optionspage_logging.cpp \
		settings/optionspage_passwords.cpp \
		settings/optionspage_proxy.cpp \
		settings/optionspage_sizeformatting.cpp \
		settings/optionspage_themes.cpp \
		settings/optionspage_transfer.cpp \
		settings/optionspage_updatecheck.cpp \
		settings/settingsdialog.cpp \
		sitemanager.cpp \
		sitemanager_controls.cpp \
		sitemanager_dialog.cpp \
		sitemanager_site.cpp \
		speedlimits_dialog.cpp \
		splitter.cpp \
		state.cpp \
		statusbar.cpp \
		statuslinectrl.cpp \
		StatusView.cpp \
		systemimagelist.cpp \
		textctrlex.cpp \
		themeprovider.cpp \
		timeformatting.cpp \
		toolbar.cpp \
		treectrlex.cpp \
		update_dialog.cpp \
		verifycertdialog.cpp \
		verifyhostkeydialog.cpp \
		view.cpp \
		viewheader.cpp \
		volume_enumerator.cpp \
		welcome_dialog.cpp \
		window_state_manager.cpp \
		wrapengine.cpp \
		wxext/spinctrlex.cpp \
		wxfilesystem_blob_handler.cpp \
		xh_text_ex.cpp \
		xmlfunctions.cpp \
		xrc_helper.cpp

noinst_HEADERS = \
		aboutdialog.h \
		asksavepassworddialog.h \
		asyncrequestqueue.h \
		aui_notebook_ex.h \
		bookmarks_dialog.h \
		buildinfo.h \
		chmoddialog.h \
		clearprivatedata.h \
		cmdline.h \
		commandqueue.h \
		conditionaldialog.h \
		context_control.h \
		customheightlistctrl.h \
		defaultfileexistsdlg.h \
		dialogex.h \
		dndobjects.h \
		dragdropmanager.h \
		dropsource.h \
		drop_target_ex.h \
		edithandler.h \
		encoding_converter.h \
		export.h \
		fileexistsdlg.h \
		filelistctrl.h \
		filelist_statusbar.h \
		filezilla.h \
		filezillaapp.h \
		filter_manager.h \
		filter_conditions_dialog.h \
		filteredit.h \
		file_utils.h \
		fzputtygen_interface.h \
		graphics.h \
		import.h \
		infotext.h \
		inputdialog.h \
		led.h \
		listctrlex.h \
		listingcomparison.h \
		list_search_panel.h \
		local_recursive_operation.h \
		locale_initializer.h \
		LocalListView.h \
		LocalTreeView.h \
		loginmanager.h \
		Mainfrm.h \
		manual_transfer.h \
		menu_bar.h \
		msgbox.h \
		netconfwizard.h \
		Options.h \
		option_change_event_handler.h \
		overlay.h \
		power_management.h \
		queue.h \
		queue_storage.h \
		QueueView.h \
		queueview_failed.h \
		queueview_successful.h \
		quickconnectbar.h \
		recentserverlist.h \
		recursive_operation_status.h \
		remote_recursive_operation.h \
		RemoteListView.h \
		RemoteTreeView.h \
		renderer.h \
		search.h \
		serverdata.h \
		settings/optionspage.h \
		settings/optionspage_connection.h \
		settings/optionspage_dateformatting.h \
		settings/optionspage_debug.h \
		settings/optionspage_edit.h \
		settings/optionspage_edit_associations.h \
		settings/optionspage_fileexists.h \
		settings/optionspage_filelists.h \
		settings/optionspage_interface.h \
		settings/optionspage_language.h \
		settings/optionspage_logging.h \
		settings/optionspage_passwords.h \
		settings/optionspage_proxy.h \
		settings/optionspage_sizeformatting.h \
		settings/optionspage_themes.h \
		settings/optionspage_transfer.h \
		settings/optionspage_updatecheck.h \
		settings/settingsdialog.h \
		sitemanager.h \
		sitemanager_controls.h \
		sitemanager_dialog.h \
		sitemanager_site.h \
		speedlimits_dialog.h \
		splitter.h \
		state.h \
		statuslinectrl.h \
		statusbar.h \
		StatusView.h \
		systemimagelist.h \
		textctrlex.h \
		themeprovider.h \
		timeformatting.h \
		toolbar.h \
		treectrlex.h \
		update_dialog.h \
		verifycertdialog.h \
		verifyhostkeydialog.h \
		view.h \
		viewheader.h \
		volume_enumerator.h \
		welcome_dialog.h \
		window_state_manager.h \
		wrapengine.h \
		wxext/spinctrlex.h \
		wxfilesystem_blob_handler.h \
		xh_text_ex.h \
		xmlfunctions.h \
		xrc_helper.h

if ENABLE_FTP
tabftp_SOURCES += \
		settings/optionspage_connection_active.cpp \
		settings/optionspage_connection_ftp.cpp \
		settings/optionspage_connection_passive.cpp \
		settings/optionspage_ftpproxy.cpp \
		settings/optionspage_filetype.cpp

noinst_HEADERS += \
		settings/optionspage_connection_active.h \
		settings/optionspage_connection_ftp.h \
		settings/optionspage_connection_passive.h \
		settings/optionspage_ftpproxy.h \
		settings/optionspage_filetype.h
endif

if ENABLE_SFTP
tabftp_SOURCES += \
		settings/optionspage_connection_sftp.cpp \
		sftp_crypt_info_dlg.cpp

noinst_HEADERS += \
		settings/optionspage_connection_sftp.h \
		sftp_crypt_info_dlg.h
endif

if ENABLE_STORJ
tabftp_SOURCES += \
		storj_key_interface.cpp

noinst_HEADERS += \
		 storj_key_interface.h
endif

if USE_RESOURCEFILE
RESOURCEFILE = resources/filezilla.o
endif

tabftp_DEPENDENCIES += ../commonui/libfzclient-commonui-private.la ../engine/libfzclient-private.la

tabftp_CPPFLAGS = -I$(top_builddir)/config
tabftp_CPPFLAGS += $(LIBFILEZILLA_CFLAGS)
tabftp_CPPFLAGS += $(WX_CPPFLAGS)
tabftp_CXXFLAGS = $(WX_CXXFLAGS_ONLY)
tabftp_CFLAGS = $(WX_CFLAGS_ONLY)

tabftp_LDFLAGS = ../commonui/libfzclient-commonui-private.la ../engine/libfzclient-private.la $(LIBFILEZILLA_LIBS)

tabftp_LDFLAGS += $(PUGIXML_LIBS)

if HAVE_DBUS
tabftp_DEPENDENCIES += ../dbus/libfzdbus.a
tabftp_LDFLAGS += ../dbus/libfzdbus.a $(LIBDBUS_LIBS)
endif

tabftp_LDFLAGS += $(WX_LIBS)
tabftp_LDFLAGS += $(RESOURCEFILE)

tabftp_CPPFLAGS += $(LIBSQLITE3_CFLAGS)
tabftp_LDFLAGS += $(LIBSQLITE3_LIBS)

if FZ_WINDOWS
tabftp_LDFLAGS += -mwindows -lnormaliz -lole32 -luuid -lnetapi32 -lmpr -lpowrprof -lws2_32 -lshlwapi
endif

# GTK+ libs, empty if not using wxGTK
tabftp_CPPFLAGS += $(LIBGTK_CFLAGS)
tabftp_LDFLAGS += $(LIBGTK_LIBS)

if FZ_WINDOWS
tabftp_DEPENDENCIES += resources/filezilla.o
endif

if HAVE_LIBPUGIXML
else
tabftp_DEPENDENCIES += $(PUGIXML_LIBS)
endif

dist_noinst_DATA = interface.vcxproj

if MACAPPBUNDLE
noinst_DATA = $(top_builddir)/TabFTP.app/Contents/MacOS/filezilla$(EXEEXT)
tabftp_LDFLAGS += libfzmac.a

if USE_MAC_SANDBOX
tabftp_SOURCES += osx_sandbox_userdirs.cpp
noinst_HEADERS += osx_sandbox_userdirs.h
endif
endif

$(top_builddir)/TabFTP.app/Contents/MacOS/filezilla$(EXEEXT): tabftp
	mkdir -p $(top_builddir)/TabFTP.app/Contents/MacOS
	mkdir -p $(top_builddir)/TabFTP.app/Contents/SharedSupport/resources
	mkdir -p $(top_builddir)/TabFTP.app/Contents/Resources
	$(MAKE) -C resources mac-copy-resources
	if test -f ".libs/filezilla"; then \
	  cp -f .libs/tabftp $(top_builddir)/TabFTP.app/Contents/MacOS/filezilla; \
	else \
	  cp -f tabftp $(top_builddir)/TabFTP.app/Contents/MacOS/filezilla; \
	fi
	cp -f $(top_srcdir)/COPYING $(top_builddir)/TabFTP.app/Contents/SharedSupport/COPYING
	mkdir -p $(top_builddir)/TabFTP.app/Contents/docs
	cp -f $(top_srcdir)/docs/fzdefaults.xml.example $(top_builddir)/TabFTP.app/Contents/docs/fzdefaults.xml.example
	cp -f $(top_srcdir)/docs/*.man $(top_builddir)/TabFTP.app/Contents/docs

CLEANFILES = filezilla.h.gch
DISTCLEANFILES = ./$(DEPDIR)/filezilla.Po
if ENABLE_PRECOMP

BUILT_SOURCES = filezilla.h.gch

-include ./$(DEPDIR)/filezilla.Po

filezilla.h.gch: filezilla.h
	if $(CXX) $(DEFS) $(DEFAULT_INCLUDES) $(INCLUDES) $(tabftp_CPPFLAGS) $(CPPFLAGS) $(tabftp_CXXFLAGS) $(CXXFLAGS) -MT $@ -MD -MP -MF "$(DEPDIR)/filezilla.Tpo" -c -o "$@" $<; \
	then mv -f "$(DEPDIR)/filezilla.Tpo" "$(DEPDIR)/filezilla.Po"; else rm -f "$(DEPDIR)/filezilla.Tpo"; exit 1; fi

endif
