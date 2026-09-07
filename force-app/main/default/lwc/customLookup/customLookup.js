import { LightningElement, api } from 'lwc';

export default class CustomLookup extends LightningElement {
    @api childObjectApiName; //= 'Opportunity'; //Contact is the default value
    @api targetFieldApiName;// = 'Requesting_User__c'; //AccountId is the default value
    @api fieldLabel;// = 'Requesting User';
    @api disabled = false;
    @api value;
    @api required;// = false;

    handleChange(event) {
        // Creates the event
        const selectedEvent = new CustomEvent('valueselected', {
            detail: event.detail.value
        });
        //dispatching the custom event
        this.dispatchEvent(selectedEvent);
    }

    @api isValid() {
        if (this.required) {
            this.template.querySelector('lightning-input-field').reportValidity();
        }
    }
}