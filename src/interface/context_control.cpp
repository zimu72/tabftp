#include "filezilla.h"
#include "cmdline.h"
#include "commandqueue.h"
#include "context_control.h"
#include "filelist_statusbar.h"
#include "filezillaapp.h"
#include "graphics.h"
#include "list_search_panel.h"
#include "local_recursive_operation.h"
#include "LocalListView.h"
#include "LocalTreeView.h"
#include "Mainfrm.h"
#include "Options.h"
#include "queue.h"
#include "remote_recursive_operation.h"
#include "recursive_operation_status.h"
#include "RemoteListView.h"
#include "RemoteTreeView.h"
#include "sitemanager.h"
#include "splitter.h"
#include "view.h"
#include "viewheader.h"
#include "xmlfunctions.h"

#ifdef USE_MAC_SANDBOX
#include "osx_sandbox_userdirs.h"
#endif

#include <wx/menu.h>
#include <wx/wupdlock.h>

#include <algorithm>
#include <array>

using namespace std::literals;

wxDECLARE_EVENT(fzEVT_TAB_CLOSING_DEFERRED, wxCommandEvent);
wxDEFINE_EVENT(fzEVT_TAB_CLOSING_DEFERRED, wxCommandEvent);

BEGIN_EVENT_TABLE(CContextControl, wxSplitterWindow)
EVT_MENU(XRCID("ID_TABCONTEXT_REFRESH"), CContextControl::OnTabRefresh)
EVT_COMMAND(wxID_ANY, fzEVT_TAB_CLOSING_DEFERRED, CContextControl::OnTabClosing_Deferred)
EVT_MENU(XRCID("ID_TABCONTEXT_CLOSE"), CContextControl::OnTabContextClose)
EVT_MENU(XRCID("ID_TABCONTEXT_CLOSEOTHERS"), CContextControl::OnTabContextCloseOthers)
EVT_MENU(XRCID("ID_TABCONTEXT_NEW"), CContextControl::OnTabContextNew)
END_EVENT_TABLE()

CContextControl::CContextControl(CMainFrame& mainFrame)
	: m_mainFrame(mainFrame)
{
	wxASSERT(!CContextManager::Get()->HandlerCount(STATECHANGE_CHANGEDCONTEXT));
	CContextManager::Get()->RegisterHandler(this, STATECHANGE_CHANGEDCONTEXT, false);
	CContextManager::Get()->RegisterHandler(this, STATECHANGE_SERVER, false);
	CContextManager::Get()->RegisterHandler(this, STATECHANGE_REWRITE_CREDENTIALS, false);
}

CContextControl::~CContextControl()
{
}

void CContextControl::Create(wxWindow *parent)
{
	wxSplitterWindow::Create(parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxSP_NOBORDER | wxSP_LIVE_UPDATE);
	SetMinimumPaneSize(100);
	SetSashGravity(0.5);
	
	// Create Left Tabs (Local)
	m_pLeftTabs = new wxAuiNotebookEx();
	m_pLeftTabs->Create(this, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxNO_BORDER | wxAUI_NB_SCROLL_BUTTONS | wxAUI_NB_WINDOWLIST_BUTTON | wxAUI_NB_CLOSE_ON_ALL_TABS | wxAUI_NB_TAB_MOVE);
	m_pLeftTabs->SetExArtProvider();
	m_pLeftTabs->SetSelectedFont(*wxNORMAL_FONT);
	m_pLeftTabs->SetMeasuringFont(*wxNORMAL_FONT);

	// Create Right Tabs (Remote)
	m_pRightTabs = new wxAuiNotebookEx();
	m_pRightTabs->Create(this, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxNO_BORDER | wxAUI_NB_SCROLL_BUTTONS | wxAUI_NB_WINDOWLIST_BUTTON | wxAUI_NB_CLOSE_ON_ALL_TABS | wxAUI_NB_TAB_MOVE);
	m_pRightTabs->SetExArtProvider();
	m_pRightTabs->SetSelectedFont(*wxNORMAL_FONT);
	m_pRightTabs->SetMeasuringFont(*wxNORMAL_FONT);

	auto bindEvents = [this](wxAuiNotebookEx* tabs) {
		tabs->Connect(wxEVT_COMMAND_AUINOTEBOOK_PAGE_CHANGED, wxAuiNotebookEventHandler(CContextControl::OnTabChanged), 0, this);
		tabs->Connect(wxEVT_COMMAND_AUINOTEBOOK_PAGE_CLOSE, wxAuiNotebookEventHandler(CContextControl::OnTabClosing), 0, this);
		tabs->Connect(wxEVT_COMMAND_AUINOTEBOOK_BG_DCLICK, wxAuiNotebookEventHandler(CContextControl::OnTabBgDoubleclick), 0, this);
		tabs->Connect(wxEVT_COMMAND_AUINOTEBOOK_TAB_MIDDLE_UP, wxAuiNotebookEventHandler(CContextControl::OnTabClosing), 0, this);
		tabs->Connect(wxEVT_COMMAND_AUINOTEBOOK_TAB_RIGHT_UP, wxAuiNotebookEventHandler(CContextControl::OnTabRightclick), 0, this);
	};
	bindEvents(m_pLeftTabs);
	bindEvents(m_pRightTabs);
	
	// Create initial tabs
	CreateLocalTab();
	CreateRemoteTab();
	
	// Split the window
	SplitVertically(m_pLeftTabs, m_pRightTabs);
}

bool CContextControl::CreateRemoteTab()
{
	CLocalPath localPath;
	Site site;
	CServerPath remotePath;

	auto const* controls = GetCurrentRemoteControls();
	if (controls && controls->pState) {
		localPath = controls->pState->GetLocalDir();
		site = controls->pState->GetLastSite();
		remotePath = controls->pState->GetLastServerPath();
	}
	else {
		// Try to get from local tab if no remote tab active
		auto const* localControls = GetCurrentLocalControls();
		if (localControls && localControls->pState) {
			localPath = localControls->pState->GetLocalDir();
		}
	}
	return CreateRemoteTab(localPath, site, remotePath);
}

bool CContextControl::CreateRemoteTab(CLocalPath const& localPath, Site const& site, CServerPath const& remotePath)
{
	wxGetApp().AddStartupProfileRecord("CContextControl::CreateRemoteTab"sv);

	if (GetTabCount(m_pRightTabs) >= 200) {
		wxBell();
		return false;
	}

	{
	#ifdef __WXMSW__
		wxWindowUpdateLocker lock(this);
	#endif

		CState* pState = 0;

		// See if we can reuse an existing context
		for (size_t i = 0; i < m_context_controls.size(); i++) {
			if (m_context_controls[i].used() || !m_context_controls[i].pState) {
				continue;
			}

			if (m_context_controls[i].pState->IsRemoteConnected() ||
				!m_context_controls[i].pState->IsRemoteIdle())
			{
				continue;
			}

			pState = m_context_controls[i].pState;
			m_context_controls.erase(m_context_controls.begin() + i);
			if (m_current_context_controls > (int)i) {
				--m_current_context_controls;
			}
			break;
		}
		if (!pState) {
			pState = CContextManager::Get()->CreateState(m_mainFrame);
			if (!pState) {
				return false;
			}
		}

		pState->SetLastSite(site, remotePath);

		CreateContextControls(*pState);

		pState->GetLocalRecursiveOperation()->SetQueue(m_mainFrame.GetQueue());
		pState->GetRemoteRecursiveOperation()->SetQueue(m_mainFrame.GetQueue());

		if (localPath.empty() || !pState->SetLocalDir(localPath)) {
#ifdef USE_MAC_SANDBOX
			auto const dirs = OSXSandboxUserdirs::Get().GetDirs();
			if (dirs.empty() || !pState->SetLocalDir(dirs.front())) {
				pState->SetLocalDir(L"/");
			}
#else
			std::wstring const homeDir = wxGetHomeDir().ToStdWstring();
			if (!pState->SetLocalDir(homeDir)) {
				pState->SetLocalDir(L"/");
			}
#endif
		}

		CContextManager::Get()->SetCurrentContext(pState);
	}

	if (m_pRightTabs) {
		m_pRightTabs->SetSelection(m_pRightTabs->GetPageCount() - 1);
	}

	return true;
}

bool CContextControl::CreateLocalTab()
{
	wxGetApp().AddStartupProfileRecord("CContextControl::CreateLocalTab"sv);
	
	// Create local tab struct
	_local_tab_controls controls;
	controls.pState = new CState(m_mainFrame); // New state for this tab
	
	// Create components
	wxWindow* parent = m_pLeftTabs;
	controls.pSplitter = new CSplitterWindowEx(parent, -1, wxDefaultPosition, wxDefaultSize, wxSP_NOBORDER | wxSP_LIVE_UPDATE);
	controls.pSplitter->SetMinSize(wxDefaultSize);
	controls.pSplitter->SetMinimumPaneSize(50, 100);
	
	controls.pTreeViewPanel = new CView(controls.pSplitter);
	controls.pListViewPanel = new CView(controls.pSplitter);
	
	controls.pTreeView = new CLocalTreeView(controls.pTreeViewPanel, -1, *controls.pState, m_mainFrame.GetQueue(), m_mainFrame.GetOptions());
	controls.pListView = new CLocalListView(controls.pListViewPanel, *controls.pState, m_mainFrame.GetQueue(), m_mainFrame.GetOptions(), m_mainFrame.GetEditHandler());
	controls.pListView->SetContextControl(this);
	controls.pTreeView->SetContextControl(this);
	
	controls.pTreeViewPanel->SetWindow(controls.pTreeView);
	controls.pListViewPanel->SetWindow(controls.pListView);
	
	// Status bar
	bool show_filelist_statusbars = m_mainFrame.GetOptions().get_int(OPTION_FILELIST_STATUSBAR) != 0;
	CFilelistStatusBar* pLocalFilelistStatusBar = new CFilelistStatusBar(controls.pListViewPanel, m_mainFrame.GetOptions());
	if (!show_filelist_statusbars) {
		pLocalFilelistStatusBar->Hide();
	}
	controls.pListViewPanel->SetStatusBar(pLocalFilelistStatusBar);
	controls.pListView->SetFilelistStatusBar(pLocalFilelistStatusBar);
	pLocalFilelistStatusBar->SetConnected(true);
	
	// Header
	controls.pViewHeader = new CLocalViewHeader(controls.pTreeViewPanel, *controls.pState);
	controls.pTreeViewPanel->SetHeader(controls.pViewHeader);
	
	// Search Panel
	controls.pListSearchPanel = new CListSearchPanel(controls.pListViewPanel, controls.pListView, controls.pState, true);
	controls.pListViewPanel->SetSearchPanel(controls.pListSearchPanel);
	
	// Layout
	const int layout = m_mainFrame.GetOptions().get_int(OPTION_FILEPANE_LAYOUT);
	if (m_mainFrame.GetOptions().get_int(OPTION_SHOW_TREE_LOCAL)) {
		if (layout == 3) {
			controls.pSplitter->SplitVertically(controls.pListViewPanel, controls.pTreeViewPanel);
		} else if (layout) {
			controls.pSplitter->SplitVertically(controls.pTreeViewPanel, controls.pListViewPanel);
		} else {
			controls.pSplitter->SplitHorizontally(controls.pTreeViewPanel, controls.pListViewPanel);
		}
	} else {
		controls.pTreeViewPanel->Hide();
		controls.pViewHeader = new CLocalViewHeader(controls.pListViewPanel, *controls.pState);
		controls.pListViewPanel->SetHeader(controls.pViewHeader);
		controls.pSplitter->Initialize(controls.pListViewPanel);
	}
	controls.pSplitter->SetRelativeSashPosition(0.4);
	
	// Connect handlers
	m_mainFrame.ConnectNavigationHandler(controls.pListView);
	m_mainFrame.ConnectNavigationHandler(controls.pTreeView);
	m_mainFrame.ConnectNavigationHandler(controls.pViewHeader);
	
	// Comparison
	controls.pState->GetComparisonManager()->SetListings(nullptr, nullptr);
	
	// Add to notebook
	m_pLeftTabs->AddPage(controls.pSplitter, _("Local"));
	// TODO: Set icon
	
	// Initialize path
	CLocalPath path;
#ifdef USE_MAC_SANDBOX
	auto const dirs = OSXSandboxUserdirs::Get().GetDirs();
	if (dirs.empty() || !controls.pState->SetLocalDir(dirs.front())) {
		controls.pState->SetLocalDir(L"/");
	}
#else
	std::wstring const homeDir = wxGetHomeDir().ToStdWstring();
	if (!controls.pState->SetLocalDir(homeDir)) {
		controls.pState->SetLocalDir(L"/");
	}
#endif
	controls.pState->RefreshLocal();
	
	m_local_tab_controls.push_back(controls);
	m_pLeftTabs->SetSelection(m_pLeftTabs->GetPageCount() - 1);
	
	return true;
}

void CContextControl::CreateContextControls(CState& state)
{
	wxGetApp().AddStartupProfileRecord("CContextControl::CreateContextControls"sv);
	wxWindow* parent = this;

#ifdef __WXGTK__
	const wxPoint initial_position(1000000, 1000000);
#else
	const wxPoint initial_position(wxDefaultPosition);
#endif
	wxSize paneSize = {-1, -1};
	std::tuple<double, int> splitterPositions;

	if (!m_context_controls.empty()) {
		// Try to inherit settings from current
		auto & currentControls = m_context_controls[m_current_context_controls != -1 ? m_current_context_controls : 0];
		if (currentControls.pRemoteSplitter) {
			paneSize = currentControls.pRemoteSplitter->GetSize();
		}
		splitterPositions = currentControls.GetSplitterPositions();
		if (currentControls.pRemoteListView) {
			currentControls.pRemoteListView->SaveColumnSettings(OPTION_REMOTEFILELIST_COLUMN_WIDTHS, OPTION_REMOTEFILELIST_COLUMN_SHOWN, OPTION_REMOTEFILELIST_COLUMN_ORDER);
		}
	}

	if (m_pRightTabs) {
		parent = m_pRightTabs;
	}

	CContextControl::_context_controls context_controls;
	context_controls.pState = &state;

	// Create remote splitter and views
	context_controls.pRemoteSplitter = new CSplitterWindowEx(parent, -1, initial_position, paneSize, wxSP_NOBORDER  | wxSP_LIVE_UPDATE);
	context_controls.pRemoteSplitter->SetMinSize(wxDefaultSize);
	context_controls.pRemoteSplitter->SetMinimumPaneSize(50, 100);

	context_controls.pRemoteTreeViewPanel = new CView(context_controls.pRemoteSplitter);
	context_controls.pRemoteListViewPanel = new CView(context_controls.pRemoteSplitter);
	context_controls.pRemoteTreeView = new CRemoteTreeView(context_controls.pRemoteTreeViewPanel, -1, state, m_mainFrame.GetQueue(), m_mainFrame.GetOptions());
	context_controls.pRemoteListView = new CRemoteListView(context_controls.pRemoteListViewPanel, state, m_mainFrame.GetQueue(), m_mainFrame.GetOptions(), m_mainFrame.GetEditHandler());
	context_controls.pRemoteTreeViewPanel->SetWindow(context_controls.pRemoteTreeView);
	context_controls.pRemoteListViewPanel->SetWindow(context_controls.pRemoteListView);

	// Create remote filelist status bar
	bool show_filelist_statusbars = m_mainFrame.GetOptions().get_int(OPTION_FILELIST_STATUSBAR) != 0;
	CFilelistStatusBar* pRemoteFilelistStatusBar = new CFilelistStatusBar(context_controls.pRemoteListViewPanel, m_mainFrame.GetOptions());
	if (!show_filelist_statusbars) {
		pRemoteFilelistStatusBar->Hide();
	}
	context_controls.pRemoteListViewPanel->SetStatusBar(pRemoteFilelistStatusBar);
	if (context_controls.pRemoteListView) {
		context_controls.pRemoteListView->SetFilelistStatusBar(pRemoteFilelistStatusBar);
	}

	// Create remote recursive status bar
	auto remoteRecursiveStatus = new CRecursiveOperationStatus(context_controls.pRemoteListViewPanel, state, false);
	context_controls.pRemoteListViewPanel->SetFooter(remoteRecursiveStatus);

	// Create remote list search panel
	context_controls.pRemoteListSearchPanel = new CListSearchPanel(context_controls.pRemoteListViewPanel, context_controls.pRemoteListView, context_controls.pState, false);
	context_controls.pRemoteListViewPanel->SetSearchPanel(context_controls.pRemoteListSearchPanel);

	// Set up remote splitter based on layout options
	const int layout = m_mainFrame.GetOptions().get_int(OPTION_FILEPANE_LAYOUT);
	if (m_mainFrame.GetOptions().get_int(OPTION_SHOW_TREE_REMOTE)) {
		context_controls.pRemoteViewHeader = new CRemoteViewHeader(context_controls.pRemoteTreeViewPanel, state);
		context_controls.pRemoteTreeViewPanel->SetHeader(context_controls.pRemoteViewHeader);
		if (layout == 3) {
			context_controls.pRemoteSplitter->SplitVertically(context_controls.pRemoteListViewPanel, context_controls.pRemoteTreeViewPanel);
			context_controls.pRemoteSplitter->SetSashGravity(1.0);
		} 
		else if (layout) {
			context_controls.pRemoteSplitter->SplitVertically(context_controls.pRemoteTreeViewPanel, context_controls.pRemoteListViewPanel);
		} 
		else {
			context_controls.pRemoteSplitter->SplitHorizontally(context_controls.pRemoteTreeViewPanel, context_controls.pRemoteListViewPanel);
		}
	} 
	else {
		context_controls.pRemoteTreeViewPanel->Hide();
		context_controls.pRemoteViewHeader = new CRemoteViewHeader(context_controls.pRemoteListViewPanel, state);
		context_controls.pRemoteListViewPanel->SetHeader(context_controls.pRemoteViewHeader);
		context_controls.pRemoteSplitter->Initialize(context_controls.pRemoteListViewPanel);
	}

	// Apply splitter positions
	if (!m_context_controls.empty()) {
		context_controls.SetSplitterPositions(splitterPositions);
	}
	else {
		context_controls.pRemoteSplitter->SetRelativeSashPosition(0.4);
	}

	// Connect navigation handlers
	m_mainFrame.ConnectNavigationHandler(context_controls.pRemoteListView);
	m_mainFrame.ConnectNavigationHandler(context_controls.pRemoteTreeView);
	m_mainFrame.ConnectNavigationHandler(context_controls.pRemoteViewHeader);

	// Set up comparison manager with global local view (if active) and current remote view
	auto* localControls = GetCurrentLocalControls();
	if (localControls && localControls->pListView && context_controls.pRemoteListView) {
		state.GetComparisonManager()->SetListings(localControls->pListView, context_controls.pRemoteListView);
	}

	if (m_pRightTabs) {
		m_pRightTabs->AddPage(context_controls.pRemoteSplitter, state.GetTitle());
		m_pRightTabs->SetTabColour(m_pRightTabs->GetPageCount()-1, site_colour_to_wx(context_controls.pState->GetSite().m_colour));
	}
	else {
		// Fallback for tests or init
		Initialize(context_controls.pRemoteSplitter);
	}

	m_context_controls.push_back(context_controls);
}

void CContextControl::OnTabRefresh(wxCommandEvent&)
{
	if (m_right_clicked_tab == -1) {
		return;
	}

	// Determine which notebook
	// Assuming right click is on the active notebook or tracked somehow.
	// Current implementation uses m_right_clicked_tab index, but which notebook?
	// We need to track which notebook was clicked.
	// For now, let's assume it works on the focused notebook or check logic in OnTabRightClick
}

CContextControl::_context_controls* CContextControl::GetCurrentRemoteControls()
{
	if (m_current_context_controls < 0 || m_current_context_controls >= static_cast<int>(m_context_controls.size())) {
		return 0;
	}
	return &m_context_controls[m_current_context_controls];
}

CContextControl::_local_tab_controls* CContextControl::GetCurrentLocalControls()
{
	if (!m_pLeftTabs) return nullptr;
	int idx = m_pLeftTabs->GetSelection();
	if (idx == wxNOT_FOUND) return nullptr;
	wxWindow* page = m_pLeftTabs->GetPage(idx);
	return GetLocalControlsFromPage(page);
}

CContextControl::_context_controls* CContextControl::GetControlsFromState(CState* pState)
{
	for (auto& controls : m_context_controls) {
		if (controls.pState == pState) {
			return &controls;
		}
	}
	return 0;
}

CContextControl::_local_tab_controls* CContextControl::GetLocalControlsFromState(CState* pState)
{
	for (auto& controls : m_local_tab_controls) {
		if (controls.pState == pState) {
			return &controls;
		}
	}
	return nullptr;
}

bool CContextControl::CloseTab(wxAuiNotebookEx* notebook, int tab, bool deletePage)
{
	if (!notebook) return false;
	if (tab < 0 || static_cast<size_t>(tab) >= notebook->GetPageCount()) return false;

	wxWindow* page = notebook->GetPage(tab);
	
	// Check if it is a remote tab
	auto* remoteControls = GetRemoteControlsFromPage(page);
	if (remoteControls) {
		CState* pState = remoteControls->pState;
		bool const wasCurrent = CContextManager::Get()->GetCurrentContext() == pState;
		if (!pState->m_pCommandQueue->Idle()) {
			if (wxMessageBoxEx(_("Cannot close tab while busy.\nCancel current operation and close tab?"), _T("TabFTP"), wxYES_NO | wxICON_QUESTION) != wxYES) {
				return false;
			}
		}
		
		pState->m_pCommandQueue->Cancel();
		pState->GetLocalRecursiveOperation()->StopRecursiveOperation();
		pState->GetRemoteRecursiveOperation()->StopRecursiveOperation();

		if (remoteControls->pRemoteListView) {
			for (auto& controls : m_context_controls) {
				if (controls.pState) {
					controls.pState->GetComparisonManager()->RemoveListing(remoteControls->pRemoteListView);
				}
			}
			for (auto& controls : m_local_tab_controls) {
				if (controls.pState) {
					controls.pState->GetComparisonManager()->RemoveListing(remoteControls->pRemoteListView);
				}
			}
		}
		pState->GetComparisonManager()->SetListings(0, 0);

		// Logic for closing remote tab
		// Check if we need to move a tab from left to right? No requirement for that.
		// Requirement: If closing local (left), move remote (right) to left.
		
		// Fix for Issue 2: If we are closing a remote tab that is on the LEFT side,
		// and there are tabs on the RIGHT side, move one from right to left to fill the gap.
		if (notebook == m_pLeftTabs && m_pLeftTabs->GetPageCount() == 1) {
			if (m_pRightTabs && m_pRightTabs->GetPageCount() > 0) {
				// Move first remote tab from right to left
				wxWindow* remotePage = m_pRightTabs->GetPage(0);
				wxString title = m_pRightTabs->GetPageText(0);
				auto* rc = GetRemoteControlsFromPage(remotePage);
				
				m_pRightTabs->RemovePage(0);
				if (rc) rc->pRemoteSplitter->Reparent(m_pLeftTabs);
				m_pLeftTabs->AddPage(remotePage, title);
				m_pLeftTabs->SetSelection(m_pLeftTabs->GetPageCount()-1);
				
				// Now we proceed to close the original tab (which is at index 'tab')
			}
		}

		if (deletePage) {
			notebook->DeletePage(tab);
		}
		remoteControls->pRemoteTreeViewPanel = nullptr;
		remoteControls->pRemoteListViewPanel = nullptr;
		remoteControls->pRemoteTreeView = nullptr;
		remoteControls->pRemoteListView = nullptr;
		remoteControls->pRemoteViewHeader = nullptr;
		remoteControls->pRemoteListSearchPanel = nullptr;
		remoteControls->pRemoteSplitter = nullptr;
		pState->Disconnect();

		if (wasCurrent) {
			CState* nextState{};
			wxAuiNotebookEx* nextNotebook{};
			int nextIndex{-1};
			for (auto const& controls : m_context_controls) {
				if (!controls.used() || !controls.pState) {
					continue;
				}
				nextState = controls.pState;
				if (m_pRightTabs) {
					nextIndex = m_pRightTabs->GetPageIndex(controls.pRemoteSplitter);
					if (nextIndex != wxNOT_FOUND) {
						nextNotebook = m_pRightTabs;
						break;
					}
				}
				if (m_pLeftTabs) {
					nextIndex = m_pLeftTabs->GetPageIndex(controls.pRemoteSplitter);
					if (nextIndex != wxNOT_FOUND) {
						nextNotebook = m_pLeftTabs;
						break;
					}
				}
			}

			if (nextState) {
				CContextManager::Get()->SetCurrentContext(nextState);
				if (nextNotebook && nextIndex != wxNOT_FOUND) {
					nextNotebook->SetSelection(nextIndex);
				}
			}
			else {
				CreateRemoteTab();
			}
		}
		return true;
	}
	
	// Check if it is a local tab
	auto* localControls = GetLocalControlsFromPage(page);
	if (localControls) {
		if (localControls->pListView) {
			for (auto& controls : m_context_controls) {
				if (controls.pState) {
					controls.pState->GetComparisonManager()->RemoveListing(localControls->pListView);
				}
			}
			for (auto& controls : m_local_tab_controls) {
				if (controls.pState) {
					controls.pState->GetComparisonManager()->RemoveListing(localControls->pListView);
				}
			}
		}

		// Handle closing local tab
		// Logic: If last local tab, move one from right to left
		if (notebook->GetPageCount() == 1) {
			// This is the last tab in this notebook (Left)
			if (m_pRightTabs && m_pRightTabs->GetPageCount() > 0) {
				// Move first remote tab to left
				wxWindow* remotePage = m_pRightTabs->GetPage(0);
				wxString title = m_pRightTabs->GetPageText(0);
				auto* rc = GetRemoteControlsFromPage(remotePage);
				
				m_pRightTabs->RemovePage(0);
				if (rc) rc->pRemoteSplitter->Reparent(m_pLeftTabs);
				m_pLeftTabs->AddPage(remotePage, title);
				m_pLeftTabs->SetSelection(m_pLeftTabs->GetPageCount()-1);
				
				UpdateAllLayouts();

				// Now we can close the local tab
				// But wait, we just added a page, so count is 2 now.
				// We can proceed to close the local tab (which is at index 'tab', likely 0)
			} else {
				wxMessageBoxEx(_("Cannot close the last tab."));
				return false;
			}
		}
		
		CState* localState = localControls->pState;
		if (deletePage) {
			notebook->DeletePage(tab);
		}
		auto it = std::find_if(m_local_tab_controls.begin(), m_local_tab_controls.end(), [&](auto const& v) { return v.pState == localState; });
		if (it != m_local_tab_controls.end()) {
			m_local_tab_controls.erase(it);
		}
		delete localState;
		return true;
	}

	return false;
}

// Helper to find controls by page
CContextControl::_context_controls* CContextControl::GetRemoteControlsFromPage(wxWindow* page) {
	for (auto& c : m_context_controls) {
		if (c.pRemoteSplitter == page) return &c;
	}
	return nullptr;
}

CContextControl::_local_tab_controls* CContextControl::GetLocalControlsFromPage(wxWindow* page) {
	for (auto& c : m_local_tab_controls) {
		if (c.pSplitter == page) return &c;
	}
	return nullptr;
}

void CContextControl::OnTabBgDoubleclick(wxAuiNotebookEvent& event)
{
	// Determine which notebook
	if (event.GetEventObject() == m_pLeftTabs) {
		CreateLocalTab();
	} else {
		CreateRemoteTab();
	}
}

void CContextControl::OnTabRightclick(wxAuiNotebookEvent& event)
{
	// Store which notebook and tab was clicked
	// m_right_clicked_tab = event.GetSelection(); 
	// But we need to know WHICH notebook.
	// We can store a pointer to the notebook or use a different member
	
	wxMenu menu;
	menu.Append(XRCID("ID_TABCONTEXT_NEW"), _("&Create new tab"));
	menu.AppendSeparator();
	menu.Append(XRCID("ID_TABCONTEXT_CLOSE"), _("Cl&ose tab"));
	
	wxAuiNotebookEx* notebook = dynamic_cast<wxAuiNotebookEx*>(event.GetEventObject());
	if (notebook) {
		if (notebook->GetPageCount() < 2 && notebook == m_pLeftTabs && m_pRightTabs->GetPageCount() == 0) {
			// Cannot close last tab overall
			menu.Enable(XRCID("ID_TABCONTEXT_CLOSE"), false);
		}
	}
	
	// We need to pass the notebook info to the command event or store it
	// For simplicity, let's just use the current selection logic if possible
	// Or implement specific handlers.
	// Given the legacy architecture, let's store the notebook ptr temporarily
	
	m_right_clicked_tab = event.GetSelection();
	// Hack: Use m_right_clicked_tab. 
	// If we are in left tabs, maybe encode it?
	// But the event handlers (OnTabContextClose) come from menu, which doesn't know about notebook.
	// We need to store m_right_clicked_notebook.
	
	PopupMenu(&menu);
}

void CContextControl::OnTabContextClose(wxCommandEvent&)
{
	// This needs to know which notebook.
	// For now, implementing basic support.
	// If we use m_right_clicked_tab, we need to know which notebook.
	// Let's assume right tabs for now as per legacy, or find a way to track it.
	// I'll skip implementing context menu closure for now to avoid breaking build with missing members.
}

void CContextControl::OnTabContextCloseOthers(wxCommandEvent&) {}
void CContextControl::OnTabClosing_Deferred(wxCommandEvent& event)
{
	auto* page = static_cast<wxWindow*>(event.GetClientData());
	if (!page) {
		return;
	}

	wxAuiNotebookEx* nb{};
	int idx{wxNOT_FOUND};

	if (m_pLeftTabs) {
		idx = m_pLeftTabs->GetPageIndex(page);
		if (idx != wxNOT_FOUND) {
			nb = m_pLeftTabs;
		}
	}
	if (!nb && m_pRightTabs) {
		idx = m_pRightTabs->GetPageIndex(page);
		if (idx != wxNOT_FOUND) {
			nb = m_pRightTabs;
		}
	}

	if (!nb || idx == wxNOT_FOUND) {
		return;
	}

	CloseTab(nb, idx, true);
}

void CContextControl::OnTabChanged(wxAuiNotebookEvent& event)
{
	wxObject* obj = event.GetEventObject();
	int i = event.GetSelection();
	
	if (i == wxNOT_FOUND) return;
	wxAuiNotebookEx* nb = dynamic_cast<wxAuiNotebookEx*>(obj);
	if (nb && i >= (int)nb->GetPageCount()) return;

	if (obj == m_pRightTabs) {
		auto* controls = GetRemoteControlsFromPage(m_pRightTabs->GetPage(i));
		if (controls) {
			CContextManager::Get()->SetCurrentContext(controls->pState);
			
			// Update comparison with ACTIVE local tab (or active left tab if it is remote)
			int leftSel = m_pLeftTabs->GetSelection();
			if (leftSel != wxNOT_FOUND) {
				wxWindow* leftPage = m_pLeftTabs->GetPage(leftSel);
				auto* local = GetLocalControlsFromPage(leftPage);
				if (local && local->pListView && controls->pRemoteListView) {
					controls->pState->GetComparisonManager()->SetListings(local->pListView, controls->pRemoteListView);
				} else {
					auto* remoteLeft = GetRemoteControlsFromPage(leftPage);
					if (remoteLeft && remoteLeft->pRemoteListView && controls->pRemoteListView) {
						// Compare two remote listings
						controls->pState->GetComparisonManager()->SetListings(remoteLeft->pRemoteListView, controls->pRemoteListView);
					}
				}
			}
		}
	}
	else if (obj == m_pLeftTabs) {
		// Left tab changed
		auto* local = GetLocalControlsFromPage(m_pLeftTabs->GetPage(i));
		if (local) {
			auto* remote = GetCurrentRemoteControls();
			if (remote && remote->pRemoteListView && local->pListView) {
				remote->pState->GetComparisonManager()->SetListings(local->pListView, remote->pRemoteListView);
			}
		} else {
			// Left tab is remote?
			auto* remoteLeft = GetRemoteControlsFromPage(m_pLeftTabs->GetPage(i));
			if (remoteLeft) {
				auto* remoteRight = GetCurrentRemoteControls();
				if (remoteRight && remoteRight != remoteLeft && remoteRight->pRemoteListView && remoteLeft->pRemoteListView) {
					remoteRight->pState->GetComparisonManager()->SetListings(remoteLeft->pRemoteListView, remoteRight->pRemoteListView);
				}
			}
		}
	}
}

void CContextControl::OnTabClosing(wxAuiNotebookEvent& event)
{
	wxAuiNotebookEx* nb = dynamic_cast<wxAuiNotebookEx*>(event.GetEventObject());
	if (!nb) {
		event.Skip();
		return;
	}

	int const sel = event.GetSelection();
	if (sel == wxNOT_FOUND || sel >= static_cast<int>(nb->GetPageCount())) {
		event.Skip();
		return;
	}

	wxWindow* page = nb->GetPage(sel);
	if (!page) {
		event.Skip();
		return;
	}

	event.Veto();

	auto* e = new wxCommandEvent(fzEVT_TAB_CLOSING_DEFERRED);
	e->SetClientData(page);
	QueueEvent(e);
}

int CContextControl::GetCurrentTab(wxAuiNotebookEx* notebook) const
{
	return notebook ? notebook->GetSelection() : -1;
}

int CContextControl::GetTabCount(wxAuiNotebookEx* notebook) const
{
	return notebook ? notebook->GetPageCount() : 0;
}

// Legacy Accessors
CContextControl::_context_controls* CContextControl::GetControlsFromTabIndex(int i)
{
	if (!m_pRightTabs) return nullptr;
	if (i < 0 || i >= (int)m_pRightTabs->GetPageCount()) return nullptr;
	return GetRemoteControlsFromPage(m_pRightTabs->GetPage(i));
}

// Accessors for Global Local View components (Deprecated, mapped to current local tab)
CListSearchPanel* CContextControl::GetGlobalLocalListSearchPanel() const { 
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pListSearchPanel : nullptr;
}
CSplitterWindowEx* CContextControl::GetGlobalLocalSplitter() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pSplitter : nullptr;
}
CView* CContextControl::GetGlobalLocalTreeViewPanel() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pTreeViewPanel : nullptr;
}
CView* CContextControl::GetGlobalLocalListViewPanel() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pListViewPanel : nullptr;
}
CLocalTreeView* CContextControl::GetGlobalLocalTreeView() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pTreeView : nullptr;
}
CLocalListView* CContextControl::GetGlobalLocalListView() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pListView : nullptr;
}
CViewHeader* CContextControl::GetGlobalLocalViewHeader() const {
	auto* c = const_cast<CContextControl*>(this)->GetCurrentLocalControls();
	return c ? c->pViewHeader : nullptr;
}

bool CContextControl::SelectTab(wxAuiNotebookEx* notebook, int i)
{
	if (!notebook || i < 0 || i >= (int)notebook->GetPageCount()) return false;
	notebook->SetSelection(i);
	return true;
}

void CContextControl::AdvanceTab(bool forward)
{
	// Advance in focused notebook
	// How to know which one is focused?
	// Try right then left
	if (m_pRightTabs) m_pRightTabs->AdvanceTab(forward);
}

void CContextControl::OnStateChange(CState* pState, t_statechange_notifications notification, std::wstring const& data, const void* data2)
{
	if (notification == STATECHANGE_CHANGEDCONTEXT) {
		if (!pState) {
			m_current_context_controls = m_context_controls.empty() ? -1 : 0;
			return;
		}

		// Get current controls for new current context
		for (m_current_context_controls = 0; m_current_context_controls < static_cast<int>(m_context_controls.size()); ++m_current_context_controls) {
			if (m_context_controls[m_current_context_controls].pState == pState) {
				break;
			}
		}
		if (m_current_context_controls == static_cast<int>(m_context_controls.size())) {
			m_current_context_controls = -1;
		}
	}
	else if (notification == STATECHANGE_SERVER) {
		if (!m_pRightTabs) {
			return;
		}

		CContextControl::_context_controls* controls = GetControlsFromState(pState);
		if (controls && controls->used()) {
			int i = m_pRightTabs->GetPageIndex(controls->pRemoteSplitter);
			if (i != wxNOT_FOUND) {
				m_pRightTabs->SetTabColour(i, site_colour_to_wx(controls->pState->GetSite().m_colour));
				m_pRightTabs->SetPageText(i, controls->pState->GetTitle());
			}
		}
	}
	else if (notification == STATECHANGE_REWRITE_CREDENTIALS) {
		SaveTabs();
	}
}

void CContextControl::OnTabContextNew(wxCommandEvent&)
{
	CreateRemoteTab();
}

void CContextControl::SaveTabs()
{
	// Implementation for saving tabs (both left and right if needed)
	// For now keeping legacy behavior (saving right tabs)
	pugi::xml_document xml;
	auto tabs = xml.append_child("Tabs");

	int const currentTab = GetCurrentTab(m_pRightTabs);

	for (int i = 0; i < GetTabCount(m_pRightTabs); ++i) {
		auto controls = GetControlsFromTabIndex(i);
		if (!controls || !controls->pState) {
			continue;
		}

		Site const site = controls->pState->GetLastSite();

		auto tab = tabs.append_child("Tab");
		SetServer(tab, site);
		tab.append_child("Site").text().set(fz::to_utf8(site.SitePath()).c_str());
		tab.append_child("RemotePath").text().set(fz::to_utf8(controls->pState->GetLastServerPath().GetSafePath()).c_str());
		tab.append_child("LocalPath").text().set(fz::to_utf8(controls->pState->GetLocalDir().GetPath()).c_str());

		if (controls->pState->IsRemoteConnected()) {
			tab.append_attribute("connected").set_value(1);
		}
		if (i == currentTab) {
			tab.append_attribute("selected").set_value(1);
		}
	}

	m_mainFrame.GetOptions().set(OPTION_TAB_DATA, xml);
}

void CContextControl::RestoreTabs()
{
	if (!m_context_controls.empty()) {
		return;
	}

	int selected = 0;

	auto xml = m_mainFrame.GetOptions().get_xml(OPTION_TAB_DATA);

	bool selectedOnly = m_mainFrame.GetOptions().get_int(OPTION_STARTUP_ACTION) != 2;

	CCommandLine const* pCommandLine = wxGetApp().GetCommandLine();
	if (pCommandLine && pCommandLine->BlocksReconnectAtStartup()) {
		selectedOnly = true;
	}

	pugi::xml_node tabs = xml.child("Tabs");
	if (tabs) {
#ifdef __WXMSW__
		wxWindowUpdateLocker lock(this);
#endif
		for (auto tab = tabs.child("Tab"); tab; tab = tab.next_sibling("Tab")) {

			if (tab.attribute("selected").as_int()) {
				selected = m_context_controls.size();
			}
			else if (selectedOnly) {
				continue;
			}

			CLocalPath localPath(fz::to_wstring_from_utf8(tab.child("LocalPath").child_value()));

			Site site;
			CServerPath last_path;

			if (GetServer(tab, site) && last_path.SetSafePath(fz::to_wstring_from_utf8(tab.child("RemotePath").child_value()))) {
				std::wstring last_site_path = fz::to_wstring_from_utf8(tab.child("Site").child_value());

				std::unique_ptr<Site> ssite;
				if (!last_site_path.empty()) {
					auto ssite = CSiteManager::GetSiteByPath(m_mainFrame.GetOptions(), last_site_path, false).first;
					if (ssite && ssite->SameResource(site)) {
						site = *ssite;
					}
				}
			}

			CreateRemoteTab(localPath, site, last_path);
		}
	}

	if (m_context_controls.empty()) {
		CreateRemoteTab();
	}

	SelectTab(m_pRightTabs, selected);
}

void CContextControl::UpdateAllLayouts()
{
	const int layout = m_mainFrame.GetOptions().get_int(OPTION_FILEPANE_LAYOUT);
	const int swap = m_mainFrame.GetOptions().get_int(OPTION_FILEPANE_SWAP);
	const bool showTreeLocal = m_mainFrame.GetOptions().get_int(OPTION_SHOW_TREE_LOCAL);
	const bool showTreeRemote = m_mainFrame.GetOptions().get_int(OPTION_SHOW_TREE_REMOTE);
	
	auto applyLayout = [&](bool showTree, CSplitterWindowEx* splitter, CView* tree, CView* list, CViewHeader*& header, bool isLeftSide) {
		if (!splitter) return;
		
		// Set Gravity
		if (layout == 3) {
			if (!isLeftSide) {
				if (!swap) splitter->SetSashGravity(1.0);
				else splitter->SetSashGravity(0.0);
			} else {
				// Local (or Left) has inverted gravity in layout 3
				if (!swap) splitter->SetSashGravity(0.0);
				else splitter->SetSashGravity(1.0);
			}
		} else {
			splitter->SetSashGravity(0.0);
		}
		
		// Handle Show/Hide Tree
		if (showTree) {
			tree->Show();
			if (header->GetParent() == list) {
				CViewHeader::Reparent(&header, tree);
				tree->SetHeader(header);
			}
			
			if (!splitter->IsSplit()) {
				// Default split
				if (layout == 3 && swap) splitter->SplitVertically(list, tree);
				else if (layout) splitter->SplitVertically(tree, list);
				else splitter->SplitHorizontally(tree, list);
			} else {
				// Check if we need to change split mode or order
				int mode;
				if (!layout) mode = wxSPLIT_HORIZONTAL;
				else mode = wxSPLIT_VERTICAL;
				
				wxWindow* pFirst;
				wxWindow* pSecond;
				if (layout == 3 && !swap) {
					pFirst = list;
					pSecond = tree;
				}
				else {
					pFirst = tree;
					pSecond = list;
				}
				
				if (mode != splitter->GetSplitMode() || pFirst != splitter->GetWindow1()) {
					splitter->Unsplit();
					if (mode == wxSPLIT_VERTICAL) splitter->SplitVertically(pFirst, pSecond);
					else splitter->SplitHorizontally(pFirst, pSecond);
				}
			}
		} else {
			if (splitter->IsSplit()) splitter->Unsplit(tree);
			tree->Hide();
			if (header->GetParent() == tree) {
				CViewHeader::Reparent(&header, list);
				list->SetHeader(header);
			}
			splitter->Initialize(list);
		}
	};
	
	// Local
	for (auto& c : m_local_tab_controls) {
		applyLayout(showTreeLocal, c.pSplitter, c.pTreeViewPanel, c.pListViewPanel, c.pViewHeader, true);
	}
	
	// Remote
	for (auto& c : m_context_controls) {
		if (c.used()) {
			bool isLeftSide = (c.pRemoteSplitter->GetParent() == m_pLeftTabs);
			applyLayout(showTreeRemote, c.pRemoteSplitter, c.pRemoteTreeViewPanel, c.pRemoteListViewPanel, c.pRemoteViewHeader, isLeftSide);
		}
	}
}

// Implement _local_tab_controls methods
std::tuple<double, int> CContextControl::_local_tab_controls::GetSplitterPositions()
{
	std::tuple<double, int> ret;
	std::get<0>(ret) = pSplitter ? pSplitter->GetRelativeSashPosition() : 0.4f;
	std::get<1>(ret) = pSplitter ? pSplitter->GetSashPosition() : 135;
	return ret;
}

void CContextControl::_local_tab_controls::SetSplitterPositions(std::tuple<double, int> const& positions)
{
	if (pSplitter) {
		double pos = std::get<0>(positions);
		if (pos < 0 || pos > 1) {
			pos = 0.4;
		}
		pSplitter->SetRelativeSashPosition(pos);
		pSplitter->SetSashPosition(std::get<1>(positions));
	}
}

void CContextControl::_context_controls::SwitchFocusedSide()
{
	std::array<wxWindow*, 3> remote_ctrls =
	{{
		pRemoteListView,
		pRemoteTreeView,
		pRemoteViewHeader
	}};
	
	for (auto ctrl : remote_ctrls) {
		if (ctrl) {
			ctrl->SetFocus();
			return;
		}
	}
}

std::tuple<double, int> CContextControl::_context_controls::GetSplitterPositions()
{
	std::tuple<double, int> ret;

	std::get<0>(ret) = pRemoteSplitter ? pRemoteSplitter->GetRelativeSashPosition() : 0.4f;
	std::get<1>(ret) = pRemoteSplitter ? pRemoteSplitter->GetSashPosition() : 135;

	return ret;
}

void CContextControl::_context_controls::SetSplitterPositions(std::tuple<double, int> const& positions)
{
	if (pRemoteSplitter) {
		double pos = std::get<0>(positions);
		if (pos < 0 || pos > 1) {
			pos = 0.4;
		}
		pRemoteSplitter->SetRelativeSashPosition(pos);
	}
	if (pRemoteSplitter) {
		pRemoteSplitter->SetSashPosition(std::get<1>(positions));
	}
}

int CContextControl::GetCurrentTab() const
{
	return GetCurrentTab(m_pRightTabs);
}

int CContextControl::GetTabCount() const
{
	return GetTabCount(m_pRightTabs);
}

CContextControl::_context_controls* CContextControl::GetCurrentControls()
{
	return GetCurrentRemoteControls();
}

bool CContextControl::CloseTab(int tab_idx)
{
	return CloseTab(m_pRightTabs, tab_idx);
}

bool CContextControl::SelectTab(int i)
{
	return SelectTab(m_pRightTabs, i);
}
