import { LightningElement, wire, track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvenirTemplates from '@salesforce/apex/avenirTemplatesButtonController.getAvenirTemplates';
import generateDocuments from '@salesforce/apex/avenirTemplatesButtonController.generateDocuments';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import Language from '@salesforce/schema/ave__Template_Configuration__c.Language__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import TEMPLATE_OBJECT from '@salesforce/schema/ave__Template_Configuration__c'

const columns = [
    { label: '', 
        fieldName: 'clientUrl', 
        type: 'button', 
        sortable: false, 
        fixedWidth: 35,
        cellAttributes: { alignment: 'center'},
        typeAttributes: {
            label : '',
            iconName : 'doctype:pdf',
            iconPosition : 'left',
            name : 'LINK',
            title : 'will navigate',
            variant : 'base'
        }
    },
    { label: 'Document Name', fieldName: 'ave__Document_Name__c', type: 'text', hideDefaultActions: true },
];

export default class LwcPicklistWithoutRecordtype extends LightningElement {
    @api recordId;

    @wire(getObjectInfo, { objectApiName: TEMPLATE_OBJECT })
    templateInfo;

    @wire(getPicklistValues,
        {
            recordTypeId: '$templateInfo.data.defaultRecordTypeId',
            fieldApiName: Language
        }
    )
    templateLanguageValues;

    
    error;
    columns = columns;

    @track
    templates = [];
    currentLanguage = "Finnish";
    selectedRows = [];

    @wire(getAvenirTemplates, { language: '$currentLanguage', recordId: '$recordId' })
    wiredGetAvenirTemplates(result){
        console.log(result.data);
        let fakeData = JSON.parse(JSON.stringify(result));
        if(fakeData.data){
            fakeData.data.forEach(element =>{
                if(element.ave__Document_Name__c != null && element.ave__Document_Name__c.lastIndexOf("-") != -1) {
                    element.ave__Document_Name__c = 
                    element.ave__Document_Name__c.substr(0, element.ave__Document_Name__c.lastIndexOf("-"));
                }
            });
            this.templates = fakeData.data;
            this.error = null;
        }else if(result.error){
            this.error = result.error;
        }
    }

    handleChange(event){
        this.template.querySelector('lightning-datatable').selectedRows = [];
        this.selectedRows = [];
        this.currentLanguage = event.detail.value;
    }

    handleRowSelected(event){
        this.selectedRows = [];
        event.detail.selectedRows.forEach(element => {
            this.selectedRows.push(element.Id);
        });
    }

    handleClick(event){
        let JSONArray = [];
        this.selectedRows.forEach(element =>{
            let tmpJSON = {};
            tmpJSON.TemplateId = element;
            JSONArray.push(tmpJSON);
        })
        console.log(JSON.stringify(JSONArray));

        this.showSuccessToast();
        this.handleClickClose();

        generateDocuments({ templatesIdsJSON : JSON.stringify(JSONArray), recordId: this.recordId })
            .then(result => {
                console.log(result.data)
            })
            .catch(error => {
                this.error = error;
                console.log(error);
            });
            
    }

    handleClickClose(){
        const closeQA = new CustomEvent('close');
        this.dispatchEvent(closeQA);
    }

    showSuccessToast() {
        const evt = new ShowToastEvent({
            title: 'Documents generation has been scheduled.',
            message: 'Success!',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    showErrorToast() {
        const evt = new ShowToastEvent({
            title: 'Documents generation has not been scheduled.',
            message: 'Some unexpected error',
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}



// export default class ApexDatatableExample extends LightningElement {

// }
