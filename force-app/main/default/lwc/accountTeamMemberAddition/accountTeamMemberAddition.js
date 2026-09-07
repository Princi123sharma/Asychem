import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTeams from '@salesforce/apex/AccountTeamMemberAdditionController.getTeams';
import getTeamMembers from '@salesforce/apex/AccountTeamMemberAdditionController.getTeamMembers';
import handleAddMemeberTeams from '@salesforce/apex/AccountTeamMemberAdditionController.handleAddMemeberTeams';

import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import ACCOUNT_TEAM_MEMBER_OBJECT from '@salesforce/schema/Team_Member__c';
import TEAM_ROLE from '@salesforce/schema/Team_Member__c.Team_Role__c';
import OPP_ACCESS from '@salesforce/schema/Team_Member__c.Opportunity_Access__c';
import CASE_ACCESS from '@salesforce/schema/Team_Member__c.Case_Access__c';
import ACCOUNT_ACCESS from '@salesforce/schema/Team_Member__c.Account_Access__c';

import groupSelectionLabel from '@salesforce/label/c.Group_Selection_Label';

export default class AccountTeamMemberAddition extends LightningElement {

    @track groupSelectionLabel = groupSelectionLabel;
    originalRecords = [];
    @api recordId;
    @track selectedTeamId;
    @track teamsOptions;
    @track user;
    @track teamMembersRecords = [];
    @track AccTeamMemberInsertRecords = [];
    @track pickListOptions;
    @track accountTeamMemberData;
    lastSavedData = [];
    @track showSpinner = false;
    @track isTeamAvailable = false;
    @track showTable = false;
    oppAccessPicklist = [];
    caseAccessPicklist = [];
    accAccessPicklist = [];

    @wire(getObjectInfo, { objectApiName: ACCOUNT_TEAM_MEMBER_OBJECT })
    objectInfo;

    //fetch picklist options
    @wire(getPicklistValues, { recordTypeId: "$objectInfo.data.defaultRecordTypeId", fieldApiName: TEAM_ROLE })

    wiredTeamPickList({ error, data }) {
        if (data) {
            this.pickListOptions = data.values;
        } else if (error) {
            console.log(error);
        }
    }

    // 
    //fetch picklist options
    @wire(getPicklistValues, { recordTypeId: "$objectInfo.data.defaultRecordTypeId", fieldApiName: OPP_ACCESS })

    wiredOppPickList({ error, data }) {
        if (data) {
            this.oppAccessPicklist = data.values;
        } else if (error) {
            console.log(error);
        }
    }
    // 
    //fetch picklist options
    @wire(getPicklistValues, { recordTypeId: "$objectInfo.data.defaultRecordTypeId", fieldApiName: ACCOUNT_ACCESS })

    wiredAccountPickList({ error, data }) {
        if (data) {
            this.accAccessPicklist = data.values;
        } else if (error) {
            console.log(error);
        }
    }
    // 
    //fetch picklist options
    @wire(getPicklistValues, { recordTypeId: "$objectInfo.data.defaultRecordTypeId", fieldApiName: CASE_ACCESS })

    wiredCasePickList({ error, data }) {
        if (data) {
            this.caseAccessPicklist = data.values;
        } else if (error) {
            console.log(error);
        }
    }

    @wire(getTeams)
    wiredGroups({ error, data }) {
        if (data) {
            this.teamsOptions = data.map(team => ({ label: team.Name, value: team.Id }));

        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    showDataTable() {
        this.showTable = true;
    }

    closeMainModal() {
        this.showTable = false;
    }

    handleGroupChange(event) {
        this.showSpinner = true;
        this.selectedTeamId = event.target.value;
        if (this.selectedTeamId) {
            this.isTeamAvailable = true;
        }
        getTeamMembers({ teamId: this.selectedTeamId})
            .then(result => {
                this.teamMembersRecords = JSON.parse(JSON.stringify(result));

                this.teamMembersRecords.forEach(teamMember => {
                    teamMember.userName = '';
                    if (teamMember.User__c) {
                        teamMember.userName = teamMember.User__r.Name;
                    }

                    teamMember.pickListOptions = this.pickListOptions;
                    teamMember.caseAccessPicklist = this.caseAccessPicklist;
                    teamMember.accAccessPicklist = this.accAccessPicklist;
                    teamMember.oppAccessPicklist = this.oppAccessPicklist;
                });

                this.showSpinner = false;
            })
            .catch(error => {
                this.showSpinner = false;
                this.showToast('Error', error.body.message || error, 'error');
            });
    }

    teamMemberColumns = [
        { label: 'User ', fieldName: 'userName', editable: false },
        {
            label: 'Team Role', fieldName: 'Team_Role__c', type: 'picklistColumn', editable: true, typeAttributes: {
                placeholder: 'Choose Team Role', options: { fieldName: 'pickListOptions' },
                value: { fieldName: 'Team_Role__c' },
                context: { fieldName: 'Id' }
            }
        },
        {
            label: 'Account Access', fieldName: 'Account_Access__c', type: 'picklistColumn', editable: true, typeAttributes: {
                placeholder: 'Choose Account Access', options: { fieldName: 'accAccessPicklist' },
                value: { fieldName: 'Account_Access__c' },
                context: { fieldName: 'Id' }
            }
        },
        {
            label: 'Case Access', fieldName: 'Case_Access__c', type: 'picklistColumn', editable: true, typeAttributes: {
                placeholder: 'Choose Case Access', options: { fieldName: 'caseAccessPicklist' },
                value: { fieldName: 'Case_Access__c' },
                context: { fieldName: 'Id' }
            }
        },
        {
            label: 'Opportunity Access', fieldName: 'Opportunity_Access__c', type: 'picklistColumn', editable: true, typeAttributes: {
                placeholder: 'Choose Opportunity Access', options: { fieldName: 'oppAccessPicklist' },
                value: { fieldName: 'Opportunity_Access__c' },
                context: { fieldName: 'Id' }
            }
        }
    ];

    handleCellChange(event) {
        const updatedCell = event.detail.draftValues[0];
        let objKeys = Object.keys(updatedCell);
        for(let teamMember of this.teamMembersRecords) {
            if(teamMember.Id == updatedCell.Id){
                teamMember[objKeys[0]] = updatedCell[objKeys[0]];
                break;
            }
        }
    }

    showToast(title, message, variant, mode) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: mode
        });
        this.dispatchEvent(evt);
    }

    async handleAddMemeberTeams() {
        if (this.selectedTeamId) {
            this.showSpinner = true;
            for(let teamMember of this.teamMembersRecords) {
                delete teamMember.User__r;
                delete teamMember.pickListOptions;
                delete teamMember.caseAccessPicklist;
                delete teamMember.accAccessPicklist;
                delete teamMember.oppAccessPicklist;
            }

            await handleAddMemeberTeams({ accId: this.recordId, accsTeamMembers: this.teamMembersRecords })
                .then((result) => {
                    this.showSpinner = false;
                    if (result) {
                        this.showToast('Success', 'Team Added Successfully!', 'success', 'dismissable');
                        this.closeMainModal();
                    }
                    else {
                        this.showToast('Error', 'An Error Occured!!', 'error', 'dismissable');
                    }
                })
                .catch(error => {
                    this.showSpinner = false;
                    this.showToast('Error', error.body.message || error, 'error');
                });
        }
        else {
            this.showToast('Error', 'Please Select a team from the dropdown !', 'error', 'dismissable');
        }
    }

}