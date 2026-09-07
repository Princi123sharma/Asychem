import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncDataForDateRange from '@salesforce/apex/MethodSyncController.syncDataForDateRange';
import getSyncTypes from '@salesforce/apex/MethodSyncController.getSyncTypes';
import { RefreshEvent } from 'lightning/refresh';
import { getLogger } from 'c/logger';

export default class MethodSyncManager extends LightningElement {
    @track startDate = '';
    @track endDate = '';
    @track selectedSyncType = '';
    @track syncTypes = [];
    @track methodName = '';
    @track isLoading = false;
    @track jobId = '';
    @track jobStatus = null;
    @track showJobStatus = false;
    @track syncInProgress = false;

    // Polling interval for job status
    statusCheckInterval;
    logger = getLogger();

    connectedCallback() {
        // Set default dates (yesterday)
        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        this.startDate = yesterday.toISOString().split('T')[0];
        this.endDate = yesterday.toISOString().split('T')[0];

        // Load sync types
        this.loadSyncTypes();
    }

    async loadSyncTypes() {
        try {
            const result = await getSyncTypes();
            this.syncTypes = result.map(type => ({
                label: type.label,
                value: type.value,
                description: type.description
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load sync types: ' + error.body.message, 'error');
            this.logger.error(error.body.message).addTag('Failed to load sync types');
            this.logger.saveLog();
        }
    }

    disconnectedCallback() {
        // Clear interval when component is destroyed
        if (this.statusCheckInterval) {
            clearInterval(this.statusCheckInterval);
        }
    }


    handleStartDateChange(event) {
        this.startDate = event.target.value;
        console.log('this.startDate '+this.startDate);
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        console.log('this.endDate '+this.endDate);
    }

    handleSyncTypeChange(event) {
        this.selectedSyncType = event.detail.value;
    }


    async handleSync() {
        console.log('handleSync '+this.startDate);
        console.log('handleSync '+this.endDate);
        this.isLoading = true;
        //this.syncInProgress = true;

        try {
            const result = await syncDataForDateRange({
                startDate: this.startDate,
                endDate: this.endDate,
                syncTypes: [this.selectedSyncType],
                methodName: this.methodName
            });

            if (result.hasError) {
                this.showToast('Error', result.message, 'error');
                this.logger.error(result.message).addTag('error occur in handleSync method');
                this.logger.info(result.message).addTag('error occur in handleSync method');
                this.logger.saveLog();
                //this.syncInProgress = false;
            } else {
                this.jobId = result.jobId;
                this.showToast('Success', result.message, 'success');
            }
        } catch (error) {
            this.showToast('Error', 'Failed to start sync: ' + error.body?.message || error.message, 'error');
            this.logger.error(error.body?.message || error.message).addTag('Failed to start sync:');
            this.logger.saveLog();
            //this.syncInProgress = false;
        } finally {
            this.isLoading = false;
            this.dispatchEvent(new RefreshEvent());
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get isFormDisabled() {
        return this.isLoading || this.syncInProgress;
    }

    get isSyncButtonDisabled() {
        if (this.isLoading || this.syncInProgress) {
            return true;
        }
        if (!this.selectedSyncType) {
            return true;
        }
        if (!this.startDate || !this.endDate || new Date(this.startDate) > new Date(this.endDate)) {
            return true;
        }
        return false;
    }

    get validationMessage() {
        if (!this.selectedSyncType) {
            return 'Please select a sync type.';
        }
        if (!this.startDate || !this.endDate || new Date(this.startDate) > new Date(this.endDate)) {
            return 'Start date must be before or the same as the end date.';
        }
        return '';
    }
}