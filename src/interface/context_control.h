#ifndef FILEZILLA_INTERFACE_CONTEXT_CONTROL_HEADER
#define FILEZILLA_INTERFACE_CONTEXT_CONTROL_HEADER

#include <wx/aui/auibook.h>
#include "state.h"

#include <memory>

class wxAuiNotebookEx;
class CLocalListView;
class CLocalTreeView;
class CMainFrame;
class CRemoteListView;
class CRemoteTreeView;
class CView;
class CViewHeader;
class CSplitterWindowEx;
class CState;
class CListSearchPanel;

class CContextControl final : public wxSplitterWindow, public CGlobalStateEventHandler
{
public:
	struct _local_tab_controls final
	{
		CView* pTreeViewPanel{};
		CView* pListViewPanel{};
		CLocalTreeView* pTreeView{};
		CLocalListView* pListView{};
		CViewHeader* pViewHeader{};
		CListSearchPanel* pListSearchPanel{};
		CSplitterWindowEx* pSplitter{};
		CState* pState{};
		
		std::tuple<double, int> GetSplitterPositions();
		void SetSplitterPositions(std::tuple<double, int> const& positions);
	};

	struct _context_controls final
	{
		bool used() const { return pRemoteSplitter != 0; }

		// List of all windows and controls assorted with a context (remote only)
		CView* pRemoteTreeViewPanel{};
		CView* pRemoteListViewPanel{};
		CRemoteTreeView* pRemoteTreeView{};
		CRemoteListView* pRemoteListView{};
		CViewHeader* pRemoteViewHeader{};
		CListSearchPanel* pRemoteListSearchPanel{};

		CSplitterWindowEx* pRemoteSplitter{};

		CState* pState{};

		void SwitchFocusedSide();
		std::tuple<double, int> GetSplitterPositions();
		void SetSplitterPositions(std::tuple<double, int> const& positions);
	};

	CContextControl(CMainFrame& mainFrame);
	virtual ~CContextControl();

	void Create(wxWindow* parent);

	// Tab creation
	bool CreateRemoteTab(); // Renamed from CreateTab
	bool CreateRemoteTab(CLocalPath const& localPath, Site const& site, CServerPath const& remotePath);
	bool CreateLocalTab();
	bool CloseTab(wxAuiNotebookEx* notebook, int tab_idx, bool deletePage = true);

	_context_controls* GetCurrentRemoteControls(); // Renamed/Clarified
	_local_tab_controls* GetCurrentLocalControls();
	
	_context_controls* GetControlsFromState(CState* pState);
	_local_tab_controls* GetLocalControlsFromState(CState* pState);

	// Helper to get controls from a specific page window
	_context_controls* GetRemoteControlsFromPage(wxWindow* page);
	_local_tab_controls* GetLocalControlsFromPage(wxWindow* page);

	int GetCurrentTab(wxAuiNotebookEx* notebook) const;
	int GetTabCount(wxAuiNotebookEx* notebook) const;
	
	// Legacy accessors wrappers
	int GetCurrentTab() const;
	int GetTabCount() const;
	_context_controls* GetCurrentControls();
	bool CreateTab() { return CreateRemoteTab(); }
	bool CloseTab(int tab_idx);

	_context_controls* GetControlsFromTabIndex(int i); // Assumes right tabs for backward compatibility for now
	
	// Accessors for tab notebooks
	wxAuiNotebookEx* GetLeftTabControl() const { return m_pLeftTabs; }
	wxAuiNotebookEx* GetRightTabControl() const { return m_pRightTabs; }

	bool SelectTab(wxAuiNotebookEx* notebook, int i);
	bool SelectTab(int i); // Legacy wrapper for remote tabs
	void AdvanceTab(bool forward); // Advances in the currently focused notebook

	void SaveTabs();
	void RestoreTabs();
	
	// Layout updates
	void UpdateAllLayouts();
	
	// Deprecated/Modified accessors for global local view components
	// These will now return the components of the *currently active* local tab
	CListSearchPanel* GetGlobalLocalListSearchPanel() const;
	CSplitterWindowEx* GetGlobalLocalSplitter() const;
	CView* GetGlobalLocalTreeViewPanel() const;
	CView* GetGlobalLocalListViewPanel() const;
	CLocalTreeView* GetGlobalLocalTreeView() const;
	CLocalListView* GetGlobalLocalListView() const;
	CViewHeader* GetGlobalLocalViewHeader() const;

protected:

	void CreateContextControls(CState& state);
	// void CreateGlobalLocalView(); // Removed

	std::vector<_context_controls> m_context_controls;
	std::vector<_local_tab_controls> m_local_tab_controls;
	
	int m_current_context_controls{-1};

	wxAuiNotebookEx* m_pLeftTabs{};
	wxAuiNotebookEx* m_pRightTabs{};
	
	int m_right_clicked_tab{-1};
	CMainFrame& m_mainFrame;

	// Global shared local view components - REMOVED/DEPRECATED
	// We keep pointers if needed for ABI but better to remove and implement accessors dynamically

protected:
	DECLARE_EVENT_TABLE()
	void OnTabRefresh(wxCommandEvent&);
	void OnTabChanged(wxAuiNotebookEvent& event);
	void OnTabClosing(wxAuiNotebookEvent& event);
	void OnTabClosing_Deferred(wxCommandEvent& event);
	void OnTabBgDoubleclick(wxAuiNotebookEvent&);
	void OnTabRightclick(wxAuiNotebookEvent& event);
	void OnTabContextClose(wxCommandEvent& event);
	void OnTabContextCloseOthers(wxCommandEvent& event);
	void OnTabContextNew(wxCommandEvent&);
	
	// New event handlers for left/right specific if needed, or generic
	void OnLeftTabClosing(wxAuiNotebookEvent& event);

	virtual void OnStateChange(CState* pState, t_statechange_notifications notification, std::wstring const&, const void*) override;



};

#endif
