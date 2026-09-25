public without sharing class SharePointUploadSessionCleanup implements Schedulable {
    public void execute(SchedulableContext context) {
        List<SharePoint_Upload_Session__c> sessions = [SELECT Id, Status__c FROM SharePoint_Upload_Session__c WHERE Status__c = 'Active' AND Expires_At__c < :System.now() LIMIT 10000];
        for (SharePoint_Upload_Session__c sessionRecord : sessions) sessionRecord.Status__c = 'Expired';
        if (!sessions.isEmpty()) update sessions;
    }
}
