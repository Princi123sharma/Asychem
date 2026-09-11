import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadFile from '@salesforce/apex/LinkEaseController.uploadFile';
import getFiles from '@salesforce/apex/LinkEaseController.getFiles';

const MAX_FILE_SIZE_BYTES = 2 * 1024 * 1024;

export default class LinkEase extends LightningElement {
    @api recordId;
    files = [];
    isUploading = false;
    uploadStatus = '';
    sharePointFiles = [];
    isLoadingFiles = false;

    get hasFiles() {
        return this.files.length > 0;
    }

    get uploadDisabled() {
        return this.isUploading || !this.hasFiles || !this.recordId;
    }

    get hasSharePointFiles() {
        return this.sharePointFiles.length > 0;
    }

    get showNoFilesMessage() {
        return !this.isLoadingFiles && !this.hasSharePointFiles;
    }

    connectedCallback() {
        this.loadFiles();
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
            await this.loadFiles();
        } catch (error) {
            const message = error?.body?.message || error?.message || 'An unexpected upload error occurred.';
            this.showToast('Upload failed', `${uploadedCount} file(s) uploaded. ${message}`, 'error');
        } finally {
            this.isUploading = false;
            this.uploadStatus = '';
        }
    }

    async loadFiles() {
        if (!this.recordId) return;
        this.isLoadingFiles = true;
        try {
            const files = await getFiles({ recordId: this.recordId });
            this.sharePointFiles = files.map((file) => ({
                ...file,
                sizeLabel: this.formatFileSize(file.size)
            }));
        } catch (error) {
            this.sharePointFiles = [];
            const message = error?.body?.message || error?.message || 'Unable to load SharePoint files.';
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
