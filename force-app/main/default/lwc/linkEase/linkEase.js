import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/LinkEaseController.uploadFile';
import createUploadSession from '@salesforce/apex/LinkEaseController.createUploadSession';
import uploadChunk from '@salesforce/apex/LinkEaseController.uploadChunk';
import getFolderTree from '@salesforce/apex/LinkEaseController.getFolderTree';
import getFolderContents from '@salesforce/apex/LinkEaseController.getFolderContents';

const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
// Microsoft Graph requires non-final chunks to be a multiple of 320 KiB.
const UPLOAD_CHUNK_SIZE = 4 * 320 * 1024;
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

    get hasFiles() {
        return this.files.length > 0;
    }

    get uploadDisabled() {
        return this.isUploading || !this.hasFiles || !this.recordId;
    }

    get currentFolderLabel() {
        return this.currentFolder?.name || 'the current folder';
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
        const children = this.currentFolder?.children || [];
        return [...children]
            .sort((left, right) => {
                if (Boolean(left.isFolder) !== Boolean(right.isFolder)) {
                    return left.isFolder ? -1 : 1;
                }
                return (left.name || '').localeCompare(right.name || '');
            })
            .map((item) => ({
                ...item,
                modifiedLabel: this.formatModified(item.lastModifiedDateTime)
            }));
    }

    get hasLibraryRows() {
        return !this.isLoadingFiles && this.libraryRows.length > 0;
    }

    get showNoFilesMessage() {
        return !this.isLoadingFiles && this.currentFolder != null && this.libraryRows.length === 0;
    }

    get columnStyles() {
        return [0, 1, 2].map((index) => ({
            index,
            style: this.columnWidths[index] ? `width: ${this.columnWidths[index]}px;` : ''
        }));
    }

    get tableStyle() {
        return this.columnWidths.length ? `width: ${this.columnWidths.reduce((total, width) => total + width, 0)}px;` : '';
    }

    connectedCallback() {
        this.loadRootFolder();
    }

    disconnectedCallback() {
        this.stopColumnResize();
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
        this.showUploadModal = true;
    }

    closeUploadModal() { if (!this.isUploading) this.showUploadModal = false; }
    stopModalPropagation(event) { event.stopPropagation(); }
    handleModalBackdropClick() { this.closeUploadModal(); }

    openInSharePoint() {
        const url = this.currentFolder?.webUrl;
        if (url) {
            window.open(url, '_blank', 'noopener');
        } else {
            this.showToast('SharePoint link unavailable',
                'The current folder does not have a SharePoint link.', 'warning');
        }
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
        this.files = selectedFiles.map((file) => ({
            file,
            name: file.name,
            sizeLabel: this.formatFileSize(file.size)
        }));
    }

    async handleUpload() {
        this.isUploading = true;
        let uploadedCount = 0;
        try {
            for (let index = 0; index < this.files.length; index += 1) {
                const item = this.files[index];
                this.uploadStatus = `Uploading ${index + 1} of ${this.files.length}: ${item.name}`;
                if (item.file.size <= 2 * 1024 * 1024) {
                    const base64Data = await this.readFileAsBase64(item.file);
                    await uploadFile({
                        recordId: this.recordId,
                        fileName: item.name,
                        base64Data,
                        folderItemId: this.currentFolder?.id
                    });
                } else {
                    const uploadUrl = await createUploadSession({
                        recordId: this.recordId,
                        fileName: item.name,
                        folderItemId: this.currentFolder?.id
                    });
                    for (let start = 0; start < item.file.size; start += UPLOAD_CHUNK_SIZE) {
                        const chunk = item.file.slice(start, Math.min(start + UPLOAD_CHUNK_SIZE, item.file.size));
                        const base64Data = await this.readBlobAsBase64(chunk);
                        await uploadChunk({ uploadUrl, base64Data, start, total: item.file.size });
                    }
                }
                uploadedCount += 1;
            }
            this.showToast('Upload complete', `${uploadedCount} file(s) uploaded to SharePoint.`, 'success');
            this.files = [];
            this.template.querySelector('lightning-input').value = null;
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
            const tree = await getFolderTree({ recordId: this.recordId });
            this.rootFolder = tree;
            this.currentFolder = tree;
            this.path = [{ id: tree.id, name: tree.name }];
        } catch (error) {
            this.rootFolder = null;
            this.currentFolder = null;
            this.path = [];
            const message = error?.body?.message || error?.message || 'Unable to load SharePoint files.';
            this.showToast('Unable to load files', message, 'error');
        } finally {
            this.isLoadingFiles = false;
        }
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
            const folder = await getFolderContents({ recordId: this.recordId, folderItemId: folderId });
            folder.name = folder.name || folderName;
            this.currentFolder = folder;
            const nextPath = this.path.slice(0, pathIndex);
            nextPath.push({ id: folder.id, name: folder.name });
            this.path = nextPath;
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Unable to open this folder.';
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
