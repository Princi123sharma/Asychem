import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import ACCOUNT_CLIENT_STATUS from '@salesforce/schema/Account.Client_Status__c';
import ACCOUNT_CATALOG_ACCOUNT from '@salesforce/schema/Account_Catalog__c.Account__c';

const ACCOUNT_ID_PREFIX = '001';
const ACCOUNT_FIELDS = [ACCOUNT_CLIENT_STATUS];
const ACCOUNT_CATALOG_FIELDS = [ACCOUNT_CATALOG_ACCOUNT];

export default class ActiveInactiveAccount extends LightningElement {
    @api recordId;
    accStatus = 'NO STATUS';
    color = 'gray';
    reason = ['Client Status is blank. Run the lifecycle batch to evaluate this account.'];
    viewDetail = false;
    relatedAccountId;

    get hasReason() {
        return this.reason && this.reason.length > 0;
    }

    get isAccountRecord() {
        return this.recordId && this.recordId.startsWith(ACCOUNT_ID_PREFIX);
    }

    get accountRecordId() {
        return this.isAccountRecord ? this.recordId : undefined;
    }

    get accountCatalogRecordId() {
        return this.isAccountRecord ? undefined : this.recordId;
    }

    @wire(getRecord, { recordId: '$accountRecordId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.applyStatus(getFieldValue(data, ACCOUNT_CLIENT_STATUS));
        } else if (error) {
            console.error('Error getting Account status: ' + JSON.stringify(error));
        }
    }

    @wire(getRecord, { recordId: '$accountCatalogRecordId', fields: ACCOUNT_CATALOG_FIELDS })
    wiredAccountCatalog({ error, data }) {
        if (data) {
            this.relatedAccountId = getFieldValue(data, ACCOUNT_CATALOG_ACCOUNT);
        } else if (error) {
            console.error('Error getting Account Catalog account lookup: ' + JSON.stringify(error));
        }
    }

    @wire(getRecord, { recordId: '$relatedAccountId', fields: ACCOUNT_FIELDS })
    wiredRelatedAccount({ error, data }) {
        if (data) {
            this.applyStatus(getFieldValue(data, ACCOUNT_CLIENT_STATUS));
        } else if (error) {
            console.error('Error getting related Account status: ' + JSON.stringify(error));
        }
    }

    applyStatus(status) {
        const backendStatus = status ? status.toUpperCase() : 'NO STATUS';

        if (backendStatus === 'ACTIVE') {
            this.accStatus = 'UNAVAILABLE';
            this.color = 'red';
            this.reason = ['Client is currently unavailable.'];
        } else if (backendStatus === 'PENDING') {
            this.accStatus = 'PENDING';
            this.color = 'orange';
            this.reason = ['Client is currently on the Pending Client List.'];
        } else if (backendStatus === 'INACTIVE') {
            this.accStatus = 'AVAILABLE';
            this.color = 'green';
            this.reason = ['Client is currently available.'];
        } else {
            this.accStatus = 'NO STATUS';
            this.color = 'gray';
            this.reason = ['Client Status is blank. Run the lifecycle batch to evaluate this account.'];
        }
    }

    handleViewDetail() {
        this.viewDetail = true;
    }

    handleOk() {
        this.viewDetail = false;
    }
}