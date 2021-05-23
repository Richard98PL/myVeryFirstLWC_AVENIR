public with sharing class avenirTemplatesButtonController {
    public static final string RECORD_TYPE_ID = 'RecordTypeId';
    public static final string SERVICE_CONTRACT = String.valueOf(Schema.ServiceContract.SObjectType);
    public static final string CONTRACT_LINE_ITEM = String.valueOf(Schema.ContractLineItem.SObjectType);
    @AuraEnabled(cacheable=true)
    public static List<ave__Template_Configuration__c> getAvenirTemplates(String language, Id recordId) {
        language = ((language == null || language == '') ? 'Finnish' : language);

        if(SERVICE_CONTRACT == recordId.getSObjectType().getDescribe().getName()){
            List<ave__Assignment_Rule__c> assignmentRules = [SELECT ave__Template_Configuration__c, 
                                                                    ave__Object_Name__c,
                                                                    ave__Rule_Condition__c FROM ave__Assignment_Rule__c
                                                                    WHERE ave__Active_Template_Configuration__c = true];

            ServiceContract contract = [SELECT Id, RecordTypeId, (SELECT Id FROM ContractLineItems) From ServiceContract WHERE Id = :recordId];
            Set<Id> matchedTemplates = new Set<Id>();

            for(ave__Assignment_Rule__c rule : assignmentRules){
                TemplateCondition ruleObject = parseTemplateCondition(rule.ave__Rule_Condition__c);
                for(Conditions condition : ruleObject.conditions){
                    if(condition.conditionLeftSide == RECORD_TYPE_ID && contract.RecordTypeId == condition.conditionRightSide){
                        matchedTemplates.add(rule.ave__Template_Configuration__c);
                    }
                }
            }
            System.debug(matchedTemplates);
            return [SELECT Id,Name,ave__Document_Name__c, LastModifiedDate
                    FROM ave__Template_Configuration__c 
                    WHERE 
                        (Language__c = :language AND
                        ave__Is_Active__c = True AND
                        ave__Document_Name__c != null AND
                        (NOT ave__Document_Name__c LIKE '%test%') AND
                        Id IN :matchedTemplates)

                        OR 

                        (ave__Skip_Assignment_Rules__c = true AND
                         ave__Object_API_Name__c =: SERVICE_CONTRACT AND
                         ave__Is_Active__c = True)
                    ];
        }else{
            return null;
        }
    }

    public class TemplateCondition {
        public String expressionType;
        public String expression;
        public List<Conditions> conditions;
    }

    public class Conditions {
        public Integer orderNumber;
        public String conditionLeftSide;
        public String conditionOperator;
        public String conditionRightSide;
    }

    public static TemplateCondition parseTemplateCondition(String json) {
        return (TemplateCondition) System.JSON.deserialize(json, TemplateCondition.class);
    }

    public class Template {
        public String TemplateId;
    }

    public static List<Template> parseTemplatesArray(String json) {
		return (List<Template>) System.JSON.deserialize(json, List<Template>.class);
	}

    @AuraEnabled
    public static String generateDocuments(String templatesIdsJSON, Id recordId) {
        List<Template> listOfTemplates = parseTemplatesArray(templatesIdsJSON);
        Set<Id> templatesIds = new Set<Id>();
        for(Template template : listOfTemplates){
            templatesIds.add(template.TemplateId);
        }

        List<ave__Template_Configuration__c> templatesRecords = [SELECT Id, ave__Object_API_Name__c FROM ave__Template_Configuration__c
                                                                 WHERE Id IN :templatesIds];

        ServiceContract contract = [SELECT Id, RecordTypeId, (SELECT Id FROM ContractLineItems) From ServiceContract WHERE Id = :recordId];
        Map<Id,Set<Id>> contractRecordsByTemplateId = new Map<Id,Set<Id>>();
        Map<Id,Set<Id>> contractLineItemRecordsByTemplateId = new Map<Id,Set<Id>>();

        for(ave__Template_Configuration__c templateRecord : templatesRecords){
            if(templateRecord.ave__Object_API_Name__c == SERVICE_CONTRACT){

                if(contractRecordsByTemplateId.get(templateRecord.Id) == null){
                    contractRecordsByTemplateId.put(templateRecord.Id, new Set<Id>{recordId});
                }else{
                    contractRecordsByTemplateId.get(templateRecord.Id).add(recordId);
                }

            }else if(templateRecord.ave__Object_API_Name__c == CONTRACT_LINE_ITEM){

                for(ContractLineItem apartment : contract.ContractLineItems){
                    if(contractLineItemRecordsByTemplateId.get(templateRecord.Id) == null){
                        contractLineItemRecordsByTemplateId.put(templateRecord.Id, new Set<Id>{apartment.Id});
                    }else{
                        contractLineItemRecordsByTemplateId.get(templateRecord.Id).add(apartment.Id);
                    }
                }

            }
        }

        ave.ApiProxy.scheduleDocumentGenerationForRecords(contractRecordsByTemplateId);
        ave.ApiProxy.scheduleDocumentGenerationForRecords(contractLineItemRecordsByTemplateId);
        return 'SUCCESS';
    }
}
