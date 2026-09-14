import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/LinkEaseController.uploadFile';
import getFolderTree from '@salesforce/apex/LinkEaseController.getFolderTree';
import getFolderContents from '@salesforce/apex/LinkEaseController.getFolderContents';

const MAX_FILE_SIZE_BYTES = 2 * 1024 * 1024;
const LIBRARY_ROOT = [
    { id: 'library-documents', name: 'Documents', isPrefix: true },
    { id: 'library-crm', name: 'CRM', isPrefix: true },
    { id: 'library-accounts', name: 'Accounts', isPrefix: true }
];

export default class LinkEase extends LightningElement {
    @api recordId;
    files = [];
    isUploading = false;
    uploadStatus = '';
    rootFolder = null;
    currentFolder = null;
    path = [];
    isLoadingFiles = false;

    get hasFiles() {
        return this.files.length > 0;
    }

    get uploadDisabled() {
        return this.isUploading || !this.hasFiles || !this.recordId;
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

    connectedCallback() {
        this.loadRootFolder();
    }

    handleFileChange(event) {
        const selectedFiles = Array.from(event.target.files);
        const oversizeFile = selectedFiles.find((file) => file.size > MAX_FILE_SIZE_BYTES);
        if (oversizeFile) {
            this.files = [];
            event.target.value = null;
            this.showToast('File too large', `${oversizeFile.name} exceeds the 2 MB limit.`, 'error');
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
                const base64Data = await this.readFileAsBase64(item.file);
                await uploadFile({ recordId: this.recordId, fileName: item.name, base64Data });
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
