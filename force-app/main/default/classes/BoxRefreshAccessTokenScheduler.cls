global class BoxRefreshAccessTokenScheduler Implements Schedulable{
    
    global void execute(SchedulableContext sc)
    {
        refreshAccessToken();
        //System.abortJob(sc.getTriggerId());
    }
    @Future(callout = true)
    global static void refreshAccessToken() {
        system.debug('in refreshhhhh aacccessss tookkeennn');
        if (BoxCCredentials__c.getValues(BoxController.SETTING_NAME) == null) {
            system.debug('Custom Setting not found!');  
        }
        else{
            BoxCCredentials__c creds = BoxCCredentials__c.getValues(BoxController.SETTING_NAME);
            HttpRequest request=new HttpRequest();
            request.setEndpoint(BoxController.ACCESS_TOKEN_URL); 
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');     
            request.setBody('client_id='+EncodingUtil.urlEncode(creds.Client_Id__c, 'UTF-8')+'&client_secret='+EncodingUtil.urlEncode(creds.Client_Secret__c, 'UTF-8')+'&refresh_token='+EncodingUtil.urlEncode(creds.Refresh_Token__c, 'UTF-8')+'&grant_type=refresh_token');        
            Http p = new Http();
            HttpResponse response = p.send(request);       
            system.debug('response-- '+response.getBody());   
            if(response.getStatusCode()==200){
                BoxController.OAuthResult oauthResult = (BoxController.OAuthResult)(JSON.deserialize(response.getBody(), BoxController.OAuthResult.class));
                creds.Access_Token__c = oauthResult.access_token;                
                creds.Refresh_Token__c = oauthResult.refresh_token;
                
                system.debug('result-- '+oauthResult); 
                update creds;
            }
            else{
                system.debug('Error---  '+response.getBody());  
            }
        }
        
    }
}