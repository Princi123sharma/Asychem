public with sharing class AccountTeamMemberAdditionController {
    
    @AuraEnabled(cacheable=true)
    public static List<Team__c> getTeams() {
        return [SELECT Id, Name FROM Team__c];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Team_Member__c> getTeamMembers(Id teamId){
        teamId = String.escapeSingleQuotes(teamId);
        return [SELECT Id, Name, Team_Role__c,User__c,User__r.Name,
                Account_Access__c,Opportunity_Access__c,Case_Access__c FROM Team_Member__c WHERE Team__c = :teamId];
    }
    
    @AuraEnabled
    public static Boolean handleAddMemeberTeams(Id accId, List<Team_Member__c> accsTeamMembers){
        try{
            
            if(accId != null){
                accId = String.escapeSingleQuotes(accId);
            }
            
            Set<Id> existingUserIds = new Set<Id>();
            Map<Id,Id> duplicateUserIds = new Map<Id,Id>();
            
            //If the user already exists in the account as a team member-starts
            if(!accsTeamMembers.isEmpty()){
                for(Team_Member__c actm: accsTeamMembers){
                    existingUserIds.add(actm.User__c);
                }
            }
            
            list<AccountTeamMember> accTeamStandard = [SELECT Id, UserId, AccountId,TeamMemberRole FROM AccountTeamMember where UserId IN: existingUserIds
                                                       AND AccountId =:accId];
            for(AccountTeamMember acc: accTeamStandard){
                duplicateUserIds.put(acc.UserId,acc.Id);
            }
            
            list<AccountTeamMember> accTeamTobeAdded = new list<AccountTeamMember>();        
            
            if(!accsTeamMembers.isEmpty()){
                for(Team_Member__c accCustom: accsTeamMembers){
                    AccountTeamMember accTeam = new AccountTeamMember();
                    
                    if(!duplicateUserIds.containsKey(accCustom.User__c)){
                        accTeam.Id = duplicateUserIds.get(accCustom.User__c);
                    }
                    
                    accTeam.AccountId = accId;
                    accTeam.AccountAccessLevel = accCustom.Account_Access__c;
                    accTeam.CaseAccessLevel = accCustom.Case_Access__c;
                    accTeam.OpportunityAccessLevel = accCustom.Opportunity_Access__c;
                    accTeam.UserId = accCustom.User__c;
                    accTeam.TeamMemberRole = accCustom.Team_Role__c;
                    accTeamTobeAdded.add(accTeam);
                }
            }
            
            if(!accTeamTobeAdded.isEmpty()){
                upsert accTeamTobeAdded;
            }
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}