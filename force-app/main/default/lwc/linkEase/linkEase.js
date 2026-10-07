import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import linkEaseLogo from '@salesforce/resourceUrl/linkEaseLogo';
import uploadFile from '@salesforce/apex/LinkEaseController.uploadFile';
import createUploadSession from '@salesforce/apex/LinkEaseController.createUploadSession';
import uploadChunk from '@salesforce/apex/LinkEaseController.uploadChunk';
import getFolderTree from '@salesforce/apex/LinkEaseController.getFolderTree';
import getFolderContents from '@salesforce/apex/LinkEaseController.getFolderContents';
import requestFolderReconciliation from '@salesforce/apex/LinkEaseController.requestFolderReconciliation';
import getFileDownloadUrl from '@salesforce/apex/LinkEaseController.getFileDownloadUrl';
import deleteFiles from '@salesforce/apex/LinkEaseController.deleteFiles';

const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
// Microsoft Graph requires non-final chunks to be a multiple of 320 KiB.
const UPLOAD_CHUNK_SIZE = 4 * 320 * 1024;
const FOLDER_RETRY_DELAY_MS = 2500;
const MAX_FOLDER_RETRIES = 12;
const LIBRARY_ROOT = [
    { id: 'library-documents', name: 'Documents', isPrefix: true },
    { id: 'library-crm', name: 'CRM', isPrefix: true },
    { id: 'library-accounts', name: 'Accounts', isPrefix: true }
];

export default class LinkEase extends LightningElement {
    @api recordId;
    files = [];
    showUploadModal = false;
    isUploading = false;
    uploadStatus = '';
    rootFolder = null;
    currentFolder = null;
    path = [];
    isLoadingFiles = false;
    columnWidths = [];
    resizeState;
    isPreparingFolders = false;
    folderPreparationAttempts = 0;
    folderPreparationTimer;
    hasRequestedFolderReconciliation = false;
    selectedItemId;
    selectedItemName;
    selectedItemWebUrl;
    selectedItemIsFolder = false;
    selectedItemIds = [];
    isDeleting = false;
    searchTerm = '';
    activeFilter = 'all';
    viewMode = 'list';
    theme = 'system';
    libraryErrorMessage = '';
    linkEaseLogoUrl = linkEaseLogo;

    get hasFiles() {
        return this.files.length > 0;
    }

    get uploadComplete() {
        return this.hasFiles && this.files.every((file) => file.progress === 100);
    }

    get modalFiles() {
        return this.files.map((file) => ({
            ...file,
            progressStyle: `width: ${file.progress || 0}%;`,
            isComplete: file.progress === 100
        }));
    }

    get uploadDisabled() {
        return this.isUploading || !this.hasFiles || !this.recordId || !this.canUploadToCurrentFolder;
    }

    get isAccountRecord() {
        return this.recordId?.startsWith('001');
    }

    get canUploadToCurrentFolder() {
        return !this.isAccountRecord || this.currentFolder?.id === this.rootFolder?.id;
    }

    get currentFolderLabel() {
        return this.currentFolder?.name || 'the current folder';
    }

    get downloadDisabled() {
        return this.selectedItemIds.length !== 1 || this.selectedItemIsFolder;
    }

    get selectedFileIds() {
        return this.libraryRows
            .filter((item) => this.selectedItemIds.includes(item.id) && !item.isFolder)
            .map((item) => item.id);
    }

    get deleteDisabled() {
        return this.isDeleting || this.selectedFileIds.length === 0;
    }

    get allFilesSelected() {
        const fileIds = (this.currentFolder?.children || [])
            .filter((item) => !item.isFolder)
            .map((item) => item.id);
        return fileIds.length > 0 && fileIds.every((id) => this.selectedItemIds.includes(id));
    }

    get folderPreparationMessage() {
        return 'Preparing your SharePoint folders. This page will update automatically.';
    }

    get currentFileCount() {
        return (this.currentFolder?.children || []).filter((item) => !item.isFolder).length;
    }

    get currentFolderSize() {
        return (this.currentFolder?.children || []).reduce((total, item) => total + (item.isFolder ? 0 : (item.size || 0)), 0);
    }

    get currentFolderSizeLabel() { return this.formatFileSize(this.currentFolderSize); }
    get selectedCount() { return this.selectedFileIds.length; }
    get showBulkActions() { return this.selectedCount > 0; }
    get showBulkDownload() { return this.selectedCount === 1 && !this.selectedItemIsFolder; }
    get isListView() { return this.viewMode === 'list'; }
    get isGridView() { return this.viewMode === 'grid'; }
    get themeToggleIcon() {
        const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        return this.theme === 'dark' || (this.theme === 'system' && prefersDark) ? '☀' : '☾';
    }
    get themeToggleLabel() {
        return this.themeToggleIcon === '☀' ? 'Switch to light theme' : 'Switch to dark theme';
    }
    get filterOptions() {
        return [
            { key: 'all', label: 'All', className: this.activeFilter === 'all' ? 'filter-chip is-active' : 'filter-chip' },
            { key: 'pdf', label: 'PDF', className: this.activeFilter === 'pdf' ? 'filter-chip is-active' : 'filter-chip' },
            { key: 'excel', label: 'Excel', className: this.activeFilter === 'excel' ? 'filter-chip is-active' : 'filter-chip' },
            { key: 'folders', label: 'Folders', className: this.activeFilter === 'folders' ? 'filter-chip is-active' : 'filter-chip' }
        ];
    }

    get breadcrumbs() {
        const crumbs = [...LIBRARY_ROOT, ...this.path];
        return crumbs.map((crumb, index) => ({
            ...crumb,
            isCurrent: index === crumbs.length - 1,
            isLast: index === crumbs.length - 1
        }));
    }

    get libraryRows() {
        const searchTerm = this.searchTerm.trim().toLowerCase();
        const children = (this.currentFolder?.children || []).filter((item) => {
            const extension = this.getFileType(item).toLowerCase();
            const matchesFilter = this.activeFilter === 'all'
                || (this.activeFilter === 'folders' && item.isFolder)
                || (this.activeFilter === 'pdf' && extension === 'pdf')
                || (this.activeFilter === 'excel' && ['xls', 'xlsx', 'csv'].includes(extension));
            return matchesFilter && (!searchTerm || (item.name || '').toLowerCase().includes(searchTerm));
        });
        return [...children]
            .sort((left, right) => {
                if (Boolean(left.isFolder) !== Boolean(right.isFolder)) {
                    return left.isFolder ? -1 : 1;
                }
                return (left.name || '').localeCompare(right.name || '');
            })
            .map((item) => ({
                ...item,
                modifiedLabel: this.formatModified(item.lastModifiedDateTime),
                fileType: this.getFileType(item),
                fileIconClass: this.getFileIconClass(item),
                sizeLabel: item.isFolder ? '--' : this.formatFileSize(item.size),
                isSelected: this.selectedItemIds.includes(item.id),
                rowClass: this.selectedItemIds.includes(item.id) ? 'is-selected' : ''
            }));
    }

    get hasLibraryRows() {
        return !this.isLoadingFiles && this.libraryRows.length > 0;
    }

    get showNoFilesMessage() {
        return !this.isLoadingFiles && this.currentFolder != null && this.libraryRows.length === 0;
    }

    get columnStyles() {
        return [0, 1, 2, 3, 4].map((index) => ({
            index,
            style: this.columnWidths[index] ? `width: ${this.columnWidths[index]}px;` : ''
        }));
    }

    get tableStyle() {
        return this.columnWidths.length ? `width: ${this.columnWidths.reduce((total, width) => total + width, 0)}px;` : '';
    }

    getFileType(item) {
        if (item.isFolder) return 'Folder';
        const name = item.name || '';
        const extensionIndex = name.lastIndexOf('.');
        return extensionIndex > 0 && extensionIndex < name.length - 1
            ? name.slice(extensionIndex + 1).toUpperCase()
            : 'File';
    }

    getFileIconClass(item) {
        if (item.isFolder) return 'folder-icon';
        const extension = this.getFileType(item).toLowerCase();
        if (extension === 'csv' || extension === 'xls' || extension === 'xlsx') return 'file-icon file-icon--excel';
        if (extension === 'pdf') return 'file-icon file-icon--pdf';
        if (extension === 'doc' || extension === 'docx') return 'file-icon file-icon--word';
        if (extension === 'ppt' || extension === 'pptx') return 'file-icon file-icon--powerpoint';
        return 'file-icon file-icon--generic';
    }

    connectedCallback() {
        const savedTheme = window.localStorage.getItem('linkease-theme');
        this.theme = savedTheme === 'dark' || savedTheme === 'light' ? savedTheme : 'system';
        this.loadRootFolder();
    }

    renderedCallback() { this.applyTheme(); }

    disconnectedCallback() {
        this.stopColumnResize();
        this.clearFolderPreparationRetry();
    }

    handleResizeStart(event) {
        event.preventDefault();
        const table = this.template.querySelector('.library-table');
        if (!table) return;

        const widths = Array.from(table.querySelectorAll('th')).map((header) => header.getBoundingClientRect().width);
        const index = Number(event.currentTarget.dataset.index);
        this.resizeState = { index, startX: event.clientX, widths };
        this.handleResizeMoveBound = this.handleResizeMove.bind(this);
        this.stopColumnResizeBound = this.stopColumnResize.bind(this);
        window.addEventListener('mousemove', this.handleResizeMoveBound);
        window.addEventListener('mouseup', this.stopColumnResizeBound);
    }

    handleResizeMove(event) {
        if (!this.resizeState) return;
        const { index, startX, widths } = this.resizeState;
        const delta = event.clientX - startX;
        const minimumWidth = 120;
        const resizedWidth = Math.max(minimumWidth, widths[index] + delta);
        const adjacentWidth = Math.max(minimumWidth, widths[index + 1] - (resizedWidth - widths[index]));
        const appliedDelta = widths[index + 1] - adjacentWidth;
        const nextWidths = [...widths];
        nextWidths[index] = widths[index] + appliedDelta;
        nextWidths[index + 1] = adjacentWidth;
        this.columnWidths = nextWidths.map((width) => Math.round(width));
    }

    stopColumnResize() {
        if (this.handleResizeMoveBound) window.removeEventListener('mousemove', this.handleResizeMoveBound);
        if (this.stopColumnResizeBound) window.removeEventListener('mouseup', this.stopColumnResizeBound);
        this.resizeState = undefined;
        this.handleResizeMoveBound = undefined;
        this.stopColumnResizeBound = undefined;
    }

    focusFileInput() {
        if (!this.canUploadToCurrentFolder) {
            this.showToast('Uploads restricted', 'From an Account record, files can only be uploaded to the Account folder.', 'warning');
            return;
        }
        this.showUploadModal = true;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleFilter(event) { this.activeFilter = event.currentTarget.dataset.filter; }
    setListView() { this.viewMode = 'list'; }
    setGridView() { this.viewMode = 'grid'; }

    toggleTheme() {
        const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
        const currentIsDark = this.theme === 'dark' || (this.theme === 'system' && prefersDark);
        this.theme = currentIsDark ? 'light' : 'dark';
        window.localStorage.setItem('linkease-theme', this.theme);
        this.applyTheme();
    }

    applyTheme() {
        const shell = this.template.querySelector('.link-ease-shell');
        if (!shell) return;
        if (this.theme === 'system') shell.removeAttribute('data-theme');
        else shell.setAttribute('data-theme', this.theme);
    }

    handleDragOver(event) { event.preventDefault(); event.currentTarget.classList.add('is-dragging'); }
    handleDragLeave(event) { event.currentTarget.classList.remove('is-dragging'); }
    handleDrop(event) {
        event.preventDefault();
        event.currentTarget.classList.remove('is-dragging');
        const droppedFiles = event.dataTransfer?.files;
        if (droppedFiles?.length) this.handleFileChange({ target: { files: droppedFiles, value: null } });
    }

    closeUploadModal() { if (!this.isUploading) this.showUploadModal = false; }
    finishUpload() {
        if (!this.uploadComplete) return;
        this.showUploadModal = false;
        this.files = [];
        const input = this.template.querySelector('.modal-file-input');
        if (input) input.value = null;
    }
    stopModalPropagation(event) { event.stopPropagation(); }
    handleModalBackdropClick() { this.closeUploadModal(); }

    openInSharePoint() {
        const url = this.selectedItemWebUrl || this.currentFolder?.webUrl;
        if (url) {
            window.open(url, '_blank', 'noopener');
        } else {
            this.showToast('SharePoint link unavailable',
                'The selected file or current folder does not have a SharePoint link.', 'warning');
        }
    }

    handleRowSelect(event) {
        this.selectItem(event.currentTarget.dataset);
    }

    handleSelectionChange(event) {
        event.stopPropagation();
        if (event.target.checked) {
            this.addSelectedItem(event.currentTarget.dataset);
        } else {
            this.removeSelectedItem(event.currentTarget.dataset.id);
        }
    }

    stopRowSelection(event) {
        event.stopPropagation();
    }

    selectItem(dataset) {
        const { id, name, url, folder } = dataset;
        this.selectedItemId = id;
        this.selectedItemName = name;
        this.selectedItemWebUrl = url;
        this.selectedItemIsFolder = folder === 'true';
        this.selectedItemIds = [id];
    }

    addSelectedItem(dataset) {
        const { id, name, url, folder } = dataset;
        this.selectedItemId = id;
        this.selectedItemName = name;
        this.selectedItemWebUrl = url;
        this.selectedItemIsFolder = folder === 'true';
        this.selectedItemIds = [...new Set([...this.selectedItemIds, id])];
    }

    removeSelectedItem(id) {
        this.selectedItemIds = this.selectedItemIds.filter((selectedId) => selectedId !== id);
        if (this.selectedItemId === id) {
            const nextId = this.selectedItemIds[this.selectedItemIds.length - 1];
            const nextItem = (this.currentFolder?.children || []).find((item) => item.id === nextId);
            if (nextItem) {
                this.selectedItemId = nextItem.id;
                this.selectedItemName = nextItem.name;
                this.selectedItemWebUrl = nextItem.webUrl;
                this.selectedItemIsFolder = Boolean(nextItem.isFolder);
            } else this.clearSelectedItem();
        }
    }

    clearSelectedItem() {
        this.selectedItemId = undefined;
        this.selectedItemName = undefined;
        this.selectedItemWebUrl = undefined;
        this.selectedItemIsFolder = false;
        this.selectedItemIds = [];
    }

    handleSelectAllFiles(event) {
        const fileIds = (this.currentFolder?.children || []).filter((item) => !item.isFolder).map((item) => item.id);
        if (event.target.checked) {
            this.selectedItemIds = [...new Set([...this.selectedItemIds, ...fileIds])];
            if (!this.selectedItemId && fileIds.length) {
                const firstFile = (this.currentFolder?.children || []).find((item) => item.id === fileIds[0]);
                if (firstFile) {
                    this.selectedItemId = firstFile.id;
                    this.selectedItemName = firstFile.name;
                    this.selectedItemWebUrl = firstFile.webUrl;
                    this.selectedItemIsFolder = false;
                }
            }
        } else {
            this.selectedItemIds = this.selectedItemIds.filter((id) => !fileIds.includes(id));
            if (!this.selectedItemIds.includes(this.selectedItemId)) this.clearSelectedItem();
        }
    }

    async copyLink() {
        const link = this.selectedItemWebUrl || this.currentFolder?.webUrl;
        if (!link) {
            this.showToast('Link unavailable', 'Select a file or load a SharePoint folder first.', 'warning');
            return;
        }
        try {
            await this.copyTextToClipboard(link);
            this.showToast('Link copied', 'The SharePoint link is ready to paste.', 'success');
        } catch (error) {
            this.showToast('Unable to copy link', 'Your browser blocked clipboard access. Copy the link from SharePoint instead.', 'error');
        }
    }

    async copyTextToClipboard(text) {
        // Clipboard API access is commonly denied inside a Salesforce Lightning iframe.
        // Use it first, then fall back to the user-gesture based browser copy command.
        if (navigator.clipboard && window.isSecureContext) {
            try {
                await navigator.clipboard.writeText(text);
                return;
            } catch (error) {
                // Continue to the compatible fallback below.
            }
        }

        const copyField = this.template.querySelector('.clipboard-fallback');
        if (!copyField) throw new Error('Clipboard fallback is unavailable.');
        copyField.value = text;
        copyField.focus();
        copyField.select();
        const copied = document.execCommand('copy');
        copyField.value = '';
        if (!copied) throw new Error('Browser copy command was blocked.');
    }

    async downloadSelectedFile() {
        if (this.downloadDisabled) return;
        try {
            const downloadUrl = await getFileDownloadUrl({ recordId: this.recordId, itemId: this.selectedItemId });
            window.open(downloadUrl, '_blank', 'noopener');
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unable to download the selected file.';
            this.showToast('Download unavailable', message, 'error');
        }
    }

    async deleteSelectedFiles() {
        const itemIds = this.selectedFileIds;
        if (!itemIds.length || this.isDeleting) return;
        const confirmed = window.confirm(`Delete ${itemIds.length} selected file(s) from SharePoint? This cannot be undone here.`);
        if (!confirmed) return;
        this.isDeleting = true;
        try {
            await deleteFiles({ recordId: this.recordId, folderItemId: this.currentFolder?.id, itemIds });
            this.clearSelectedItem();
            await this.handleRefresh();
            this.showToast('Files deleted', `${itemIds.length} file(s) deleted from SharePoint.`, 'success');
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unable to delete the selected files.';
            this.showToast('Delete failed', message, 'error');
        } finally {
            this.isDeleting = false;
        }
    }

    exportCurrentTable() {
        const escape = (value) => `"${String(value || '').replace(/"/g, '""')}"`;
        const rows = [
            ['Name', 'File Type', 'Modified', 'Created By', 'SharePoint Link'],
            ...this.libraryRows.map((item) => [item.name, item.fileType, item.modifiedLabel, item.lastModifiedBy, item.webUrl])
        ];
        const csv = rows.map((row) => row.map(escape).join(',')).join('\r\n');
        const file = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(file);
        const anchor = document.createElement('a');
        anchor.href = url;
        anchor.download = 'LinkEase-Files.csv';
        anchor.click();
        URL.revokeObjectURL(url);
    }

    handleFileChange(event) {
        const selectedFiles = Array.from(event.target.files);
        const oversizeFile = selectedFiles.find((file) => file.size > MAX_FILE_SIZE_BYTES);
        if (oversizeFile) {
            this.files = [];
            this.showUploadModal = false;
            event.target.value = null;
            this.showToast('File too large', `${oversizeFile.name} exceeds the 50 MB limit.`, 'error');
            return;
        }
        this.files = selectedFiles.map((file, index) => ({
            id: `${file.name}-${file.lastModified}-${index}`,
            file,
            name: file.name,
            sizeLabel: this.formatFileSize(file.size),
            progress: 0
        }));
        // Selecting files starts one multi-file upload session. The Done
        // button appears only after every selected file has finished.
        this.handleUpload();
    }

    updateFileProgress(fileId, progress) {
        this.files = this.files.map((file) => file.id === fileId ? { ...file, progress } : file);
    }

    async handleUpload() {
        if (!this.canUploadToCurrentFolder) {
            this.showToast('Uploads restricted', 'From an Account record, files can only be uploaded to the Account folder.', 'warning');
            return;
        }
        this.isUploading = true;
        let uploadedCount = 0;
        try {
            for (let index = 0; index < this.files.length; index += 1) {
                const item = this.files[index];
                this.uploadStatus = `Uploading ${index + 1} of ${this.files.length}: ${item.name}`;
                this.updateFileProgress(item.id, 10);
                if (item.file.size <= 2 * 1024 * 1024) {
                    const base64Data = await this.readFileAsBase64(item.file);
                    await uploadFile({
                        recordId: this.recordId,
                        fileName: item.name,
                        base64Data,
                        folderItemId: this.currentFolder?.id
                    });
                } else {
                    const sessionResult = await createUploadSession({
                        recordId: this.recordId,
                        fileName: item.name,
                        folderItemId: this.currentFolder?.id,
                        totalSize: item.file.size
                    });
                    for (const sessionId of sessionResult.sessionIds) {
                        for (let start = 0; start < item.file.size; start += UPLOAD_CHUNK_SIZE) {
                            const chunk = item.file.slice(start, Math.min(start + UPLOAD_CHUNK_SIZE, item.file.size));
                            const base64Data = await this.readBlobAsBase64(chunk);
                            await uploadChunk({ sessionId, base64Data, start, total: item.file.size });
                            this.updateFileProgress(item.id, Math.min(99, Math.round(((start + chunk.size) / item.file.size) * 100)));
                        }
                    }
                }
                this.updateFileProgress(item.id, 100);
                uploadedCount += 1;
            }
            this.showToast('Upload complete', `${uploadedCount} file(s) uploaded to SharePoint.`, 'success');
            await this.handleRefresh();
        } catch (error) {
            const message = error?.body?.message || error?.message || 'An unexpected upload error occurred.';
            this.showToast('Upload failed', `${uploadedCount} file(s) uploaded. ${message}`, 'error');
        } finally {
            this.isUploading = false;
            this.uploadStatus = '';
        }
    }

    async loadRootFolder() {
        if (!this.recordId) return;
        this.isLoadingFiles = true;
        try {
            this.libraryErrorMessage = '';
            const tree = await getFolderTree({ recordId: this.recordId });
            this.rootFolder = tree;
            this.currentFolder = tree;
            this.path = [{ id: tree.id, name: tree.name }];
            this.clearSelectedItem();
            this.isPreparingFolders = false;
            this.folderPreparationAttempts = 0;
            this.hasRequestedFolderReconciliation = false;
            this.clearFolderPreparationRetry();
            if (tree.isFallback) {
                await this.requestFolderReconciliationIfNeeded();
            }
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            this.rootFolder = null;
            this.currentFolder = null;
            this.path = [];
            const message = error?.body?.message || error?.message || 'Unable to load SharePoint files.';
            if (message.includes('SharePoint folders are being prepared')) {
                this.isPreparingFolders = true;
                await this.requestFolderReconciliationIfNeeded();
                this.scheduleFolderPreparationRetry();
            } else {
                this.libraryErrorMessage = message;
                this.showToast('Unable to load files', message, 'error');
            }
        } finally {
            this.isLoadingFiles = false;
        }
    }

    async requestFolderReconciliationIfNeeded() {
        if (this.hasRequestedFolderReconciliation || !this.recordId) return;
        this.hasRequestedFolderReconciliation = true;
        try {
            await requestFolderReconciliation({ recordId: this.recordId });
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unable to request folder preparation.';
            this.showToast('Folder preparation delayed', message, 'warning');
        }
    }

    scheduleFolderPreparationRetry() {
        if (this.folderPreparationTimer || this.folderPreparationAttempts >= MAX_FOLDER_RETRIES) return;
        this.folderPreparationAttempts += 1;
        this.folderPreparationTimer = setTimeout(() => {
            this.folderPreparationTimer = undefined;
            this.loadRootFolder();
        }, FOLDER_RETRY_DELAY_MS);
    }

    clearFolderPreparationRetry() {
        if (this.folderPreparationTimer) clearTimeout(this.folderPreparationTimer);
        this.folderPreparationTimer = undefined;
    }

    async handleRefresh() {
        const current = this.path[this.path.length - 1];
        if (!current || current.id === this.rootFolder?.id) {
            await this.loadRootFolder();
            return;
        }
        await this.openFolder(current.id, current.name, this.path.length - 1);
    }

    async handleFolderOpen(event) {
        const { id, name } = event.currentTarget.dataset;
        await this.openFolder(id, name, this.path.length);
    }

    async handleBreadcrumbClick(event) {
        const { id } = event.currentTarget.dataset;
        const prefix = LIBRARY_ROOT.find((crumb) => crumb.id === id);
        if (prefix) {
            await this.loadRootFolder();
            return;
        }
        const index = this.path.findIndex((crumb) => crumb.id === id);
        if (index < 0) return;
        if (index === 0) {
            await this.loadRootFolder();
            return;
        }
        await this.openFolder(id, this.path[index].name, index);
    }

    async openFolder(folderId, folderName, pathIndex) {
        if (!this.recordId || !folderId) return;
        this.isLoadingFiles = true;
        try {
            this.libraryErrorMessage = '';
            const folder = await getFolderContents({ recordId: this.recordId, folderItemId: folderId });
            folder.name = folder.name || folderName;
            this.currentFolder = folder;
            this.clearSelectedItem();
            const nextPath = this.path.slice(0, pathIndex);
            nextPath.push({ id: folder.id, name: folder.name });
            this.path = nextPath;
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unable to open this folder.';
            this.libraryErrorMessage = message;
            this.showToast('Unable to load files', message, 'error');
        } finally {
            this.isLoadingFiles = false;
        }
    }

    readFileAsBase64(file) {
        return this.readBlobAsBase64(file);
    }

    readBlobAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(new Error(`Unable to read ${file.name}.`));
            reader.readAsDataURL(file);
        });
    }

    formatFileSize(bytes) {
        if (!bytes && bytes !== 0) return '';
        return bytes < 1024 * 1024 ? `${Math.ceil(bytes / 1024)} KB` : `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }

    formatModified(value) {
        if (!value) return '';
        const modified = new Date(value);
        if (Number.isNaN(modified.getTime())) return value;
        const diffMs = Date.now() - modified.getTime();
        const minutes = Math.floor(diffMs / 60000);
        if (minutes < 1) return 'Just now';
        if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
        const days = Math.floor(hours / 24);
        if (days < 30) return `${days} day${days === 1 ? '' : 's'} ago`;
        return modified.toLocaleDateString();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
