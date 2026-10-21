@IsTest
private class SharePointUploadSessionCleanupTest {
    @IsTest
    static void expiresOnlyActiveSessionsPastTheirExpiryTime() {
        SharePoint_Upload_Session__c expiredSession = new SharePoint_Upload_Session__c(
            Status__c = 'Active',
            Expires_At__c = System.now().addMinutes(-1)
        );
        SharePoint_Upload_Session__c activeSession = new SharePoint_Upload_Session__c(
            Status__c = 'Active',
            Expires_At__c = System.now().addMinutes(30)
        );
        SharePoint_Upload_Session__c completedSession = new SharePoint_Upload_Session__c(
            Status__c = 'Completed',
            Expires_At__c = System.now().addMinutes(-1)
        );
        insert new List<SharePoint_Upload_Session__c>{
            expiredSession, activeSession, completedSession
        };

        new SharePointUploadSessionCleanup().execute(null);

        Map<Id, SharePoint_Upload_Session__c> sessionsById = new Map<Id, SharePoint_Upload_Session__c>([
            SELECT Status__c FROM SharePoint_Upload_Session__c
            WHERE Id IN :new Set<Id>{ expiredSession.Id, activeSession.Id, completedSession.Id }
        ]);
        System.assertEquals('Expired', sessionsById.get(expiredSession.Id).Status__c);
        System.assertEquals('Active', sessionsById.get(activeSession.Id).Status__c);
        System.assertEquals('Completed', sessionsById.get(completedSession.Id).Status__c);
    }
}
