# TabFTP

based on FileZilla Client

### Introduction

TabFTP Client is a fast, reliable cross-platform FTP, FTPS, and SFTP client featuring rich functionality and an intuitive graphical user interface. Built upon the renowned open-source FileZilla Client, it inherits all core capabilities of FileZilla while introducing a deep architectural enhancement to the multi-tab interface—specifically engineered for efficient multi-site workflow management.

### Features

1. **One-to-Many Tab Architecture**  
   Global shared local file browser on the left (unified workspace for all tabs); independent remote server sessions in right-side tabs. Switching tabs updates only the remote view while preserving the local workspace context—dramatically streamlining multi-server operations.

2. **Enforced Single-Instance Operation**  
   Launch detection prevents duplicate instances. New connection requests (command line, `.fzs` files, shortcuts) are routed via IPC to the main window and opened in a new remote tab—eliminating redundant windows and optimizing system resources.

3. **Intelligent Tab Management**  
   Drag-and-drop tab reordering, keyboard shortcuts (Ctrl+T/W/Tab), context menu (reconnect/copy connection/open in new tab), status indicators. Session data auto-saved on exit with optional restore on startup.

4. **Batch Upload to All Remote Sites**  
   Context menu item "Upload to All Remote Sites" appears in local file list when ≥1 remote site is connected. Uploads selected items to current directory of every active remote tab with real-time progress tracking, fault-tolerant execution (skips failures without halting), and post-upload summary report (success/failure counts). Configurable serial or parallel transfer mode.

5. **Unified Transfer Queue**  
   Centralized queue displays all transfers across tabs with clear source-tab labeling. Full control: pause/resume/cancel individual or all tasks. Upload/download logic precisely bound to the active remote tab.

6. **Precise State Isolation & Sharing**  
   Local path, selection state, and panel layout shared globally; each remote tab independently maintains connection details, directory path, browsing history, and session state—ensuring continuity without cross-tab interference.

7. **Remote-to-Remote Transfer**  
   The first remote tab is automatically mapped to the left local panel, enabling direct drag-and-drop file transfers between remote server tabs. The system intelligently mediates transfers via a temporary local cache—eliminating manual download-upload cycles and accelerating cross-server file migration.

8. **100% Native Feature Retention**  
   Fully preserves all original FileZilla capabilities: Site Manager, bookmarks, synchronized browsing, FTP/FTPS/SFTP protocols, transfer queue, log windows, and more—zero feature loss, zero learning curve for existing users.

> 📌 Note: For complete documentation of original FileZilla features, please refer to the `readme_filezilla` file included in the project distribution.

![image-20260205221021115](./image-20260205221021115.png)