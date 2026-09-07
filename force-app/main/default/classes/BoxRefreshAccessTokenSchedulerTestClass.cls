@istest
global class BoxRefreshAccessTokenSchedulerTestClass {
    global static testMethod void testschedule() {
        BoxCCredentials__c customSetting = new BoxCCredentials__c(name='Box_Credentials',Client_Id__c='12345678',Client_Secret__c='12345678',Access_Token__c='12345678',Refresh_Token__c='12345678');
        insert customSetting;
        Test.StartTest();
        Test.setMock(HttpCalloutMock.class,new Mock());
        Datetime scheduleTime=Datetime.now();
        scheduleTime=scheduleTime.addSeconds(2);
        String hour = String.valueOf(scheduleTime.hour());
        String min = String.valueOf(scheduleTime.minute()); 
        String ss = String.valueOf(scheduleTime.second());
        
        //parse to cron expression
        String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';
        
        BoxRefreshAccessTokenScheduler s = new BoxRefreshAccessTokenScheduler(); 
        System.schedule('Job Started At ' + String.valueOf(Datetime.now()), nextFireTime, s);  
        Test.stopTest();
    }
    
    global static testMethod void testRefreshAccessToken() {
        BoxCCredentials__c customSetting = new BoxCCredentials__c(name='Box_Credentials',Client_Id__c='12345678',Client_Secret__c='12345678',Access_Token__c='12345678',Refresh_Token__c='12345678');
        insert customSetting;
        Test.StartTest();
        Test.setMock(HttpCalloutMock.class,new Mock());
        BoxRefreshAccessTokenScheduler.refreshAccessToken();
        Test.stopTest();
    }
    
    public class Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) 
        {   system.debug('getEnd'+req.getEndpoint());
         
         string fullJson = '{"access_token" : "1234567890" , "refresh_token" : "12345678"}';
         HTTPResponse res = new HTTPResponse();
         res.setBody(fullJson);
         res.setStatusCode(200);
         res.setStatus('OK');
         return res;  
         
        }
    }
}