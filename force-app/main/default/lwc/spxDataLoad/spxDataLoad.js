import { LightningElement, track } from 'lwc';
import loadCsv from '@salesforce/apex/SPX_DataLoadController.loadCsv';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DEFS = [
    {
        key: 'Projects',
        label: 'Project Enrichment',
        description: 'Matches an existing project by CC Project ID, then by Project Reference (and updates it, including the CC Project ID). If neither matches, creates a new project.',
        file: 'SPX_Projects_Template.csv',
        headers: 'Project_Reference__c,CC_Project_ID__c,Name,Vertical__c,Project_Phase__c,Project_Status__c,Project_Source__c,Estimated_Construction_Value__c,City__c,State__c,Postal_Code__c,Territory__c,Estimated_Construction_Start__c,Estimated_Completion__c',
        sample: ',CC-DEMO-0001,Sample Hospital Expansion,Healthcare,Design Development,Active,ConstructConnect,25000000,Chicago,IL,60601,Midwest,2027-03-01,2028-06-30'
    },
    {
        key: 'Leads',
        label: 'Leads',
        description: 'Matched to an existing lead by CC Project ID + Brand + Market (update), else created. Project fills the lead project only when empty.',
        file: 'SPX_Leads_Template.csv',
        headers: 'FirstName,LastName,Company,Title,Email,Phone,Status,LeadSource,Intelligence_Source__c,Project_Name__c,Vertical__c,Project_Phase__c,Engineer_of_Record__r.AccountNumber,Est_Construction_Value__c,Estimated_Bid_Date__c,CC_Project_ID__c,Project__r.CC_Project_ID__c,Brand__c,Est_Brand_Potential__c,Potential_Basis__c,BOD_Status__c,Territory__c,State,City,PostalCode,First_Contact_with_Engineer__r.Username,Description,Industry',
        sample: 'Jane,Doe,Sample Engineering LLC,Principal Engineer,jane.doe@example.com,312-555-0100,New,ConstructConnect,ConstructConnect,Sample Hospital Expansion,Healthcare,Design Development,A43836686,25000000,2027-01-15,CC-DEMO-0001,CC-DEMO-0001,Cooling,400000,Cooling tower count x avg price,Pending,Midwest,IL,Chicago,60601,jsengr@accenture.com.spx.demo,Key lead from engineer meeting,Construction'
    },
    {
        key: 'Stakeholders',
        label: 'Project Stakeholders',
        description: 'Link accounts (by Account Number) to projects with a relationship type and status.',
        file: 'SPX_Stakeholders_Template.csv',
        headers: 'Project__r.CC_Project_ID__c,Account__r.AccountNumber,Relationship_Type__c,Status__c',
        sample: 'CC-DEMO-0001,A43836686,Engineer,Pending'
    },
    {
        key: 'Insights',
        label: 'Project Insights',
        description: 'Add insights to a project (Project ID). Opportunity is optional; if both are given the opportunity must belong to the project.',
        file: 'SPX_Insights_Template.csv',
        headers: 'Project__r.CC_Project_ID__c,Opportunity__r.External_ID__c,Name,Brand__c,Insight_Type__c,Project_Intelligence_Type__c,Share_with_Project__c,Detailed_Notes__c',
        sample: 'CC-DEMO-0001,,Spec calls for two-cell cooling tower,Cooling,Project Intelligence,Channel Conflict,true,Engineer confirmed basis of design.'
    },
    {
        key: 'Competitors',
        label: 'Competitors',
        description: 'Add competitors to a project (Project ID). Opportunity is optional; if both are given the opportunity must belong to the project.',
        file: 'SPX_Competitors_Template.csv',
        headers: 'Name,Project__r.CC_Project_ID__c,Opportunity__r.External_ID__c,Competitor_Account__r.AccountNumber,Brand__c,Referenced_in_Spec__c,Strengths__c,Weaknesses__c',
        sample: 'Acme Partners,CC-DEMO-0001,,A45475905,Cooling;Marley,false,Local presence,Longer lead times'
    }
];

export default class SpxDataLoad extends LightningElement {
    @track raw = DEFS.map((d) => ({
        ...d,
        selected: false,
        fileName: '',
        csv: '',
        rowCount: 0,
        result: null
    }));
    isLoading = false;

    get cards() {
        return this.raw.map((c) => {
            const r = c.result;
            return {
                ...c,
                createdLabel: r ? `${r.created} created` : '',
                updatedLabel: r ? `${r.updated} updated` : '',
                failedLabel: r ? `${r.failed} failed` : '',
                failedClass: r && r.failed > 0 ? 'slds-theme_error slds-m-left_x-small' : 'slds-m-left_x-small',
                fatalError: r && r.fatalError ? r.fatalError : '',
                hasResultFiles: !!(r && !r.fatalError),
                successDisabled: !(r && r.created + r.updated > 0),
                errorDisabled: !(r && r.failed > 0),
                successFileLabel: r ? `Success file (${r.created + r.updated})` : '',
                errorFileLabel: r ? `Error file (${r.failed})` : '',
                errorRows: r ? r.errors.map((t, i) => ({ key: `${c.key}${i}`, text: t })) : []
            };
        });
    }

    get ready() {
        return this.raw.filter((c) => c.selected && c.csv);
    }

    get loadDisabled() {
        return this.isLoading || this.ready.length === 0;
    }

    get loadLabel() {
        return this.ready.length > 1 ? `Load ${this.ready.length} objects` : 'Load selected';
    }

    find(key) {
        return this.raw.find((c) => c.key === key);
    }

    handleSelect(e) {
        this.find(e.target.dataset.key).selected = e.target.checked;
    }

    handleFile(e) {
        const card = this.find(e.target.dataset.key);
        const file = e.target.files && e.target.files[0];
        if (!file) {
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            card.csv = reader.result;
            card.fileName = file.name;
            card.rowCount = Math.max(0, reader.result.split(/\r?\n/).filter((l) => l.trim()).length - 1);
            card.selected = true;
            card.result = null;
        };
        reader.readAsText(file);
    }

    handleTemplate(e) {
        const d = this.find(e.target.dataset.key);
        const a = document.createElement('a');
        a.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(`${d.headers}\n${d.sample}\n`);
        a.download = d.file;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    handleResultFile(e) {
        const c = this.find(e.target.dataset.key);
        const kind = e.target.dataset.kind;
        const text = kind === 'success' ? c.result.successCsv : c.result.errorCsv;
        this.download(`SPX_${c.key}_${kind}_results.csv`, text);
    }

    download(name, text) {
        const a = document.createElement('a');
        a.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(text);
        a.download = name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    handleClear() {
        this.raw.forEach((c) => {
            c.selected = false;
            c.csv = '';
            c.fileName = '';
            c.rowCount = 0;
            c.result = null;
        });
    }

    async handleLoad() {
        this.isLoading = true;
        let created = 0;
        let updated = 0;
        let failed = 0;
        for (const c of this.ready) {
            try {
                // eslint-disable-next-line no-await-in-loop
                const r = await loadCsv({ objectKey: c.key, csvText: c.csv });
                c.result = r;
                created += r.created;
                updated += r.updated;
                failed += r.failed;
            } catch (err) {
                c.result = {
                    created: 0,
                    updated: 0,
                    failed: 0,
                    errors: [],
                    fatalError: (err.body && err.body.message) || err.message
                };
            }
        }
        this.isLoading = false;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Load finished',
                message: `${created} created, ${updated} updated, ${failed} failed.`,
                variant: failed > 0 ? 'warning' : 'success'
            })
        );
    }
}
