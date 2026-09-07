@isTest
public class TestAccountTeamMemberAdditionController {

    static testMethod void createData(){
        Team__c team = new Team__c();
        team.name = 'Account Team';
        insert team;
        
        Team_Member__c actMember = new Team_Member__c();
        actMember.Team__c = team.Id;
        actMember.Team_Role__c = 'Sales Rep';
        actMember.Account_Access__c = 'Read';
        actMember.Case_Access__c = 'Read';
        actMember.Opportunity_Access__c ='Read';
        actMember.User__c = UserInfo.getUserId();
        insert actMember;        
        
        test.startTest();
        Account acc = new Account(name='test',Nick_Name__c='test');
        insert acc;
        
        accountTeamMemberAdditionController.getTeams();
        accountTeamMemberAdditionController.getTeamMembers(team.Id);
        accountTeamMemberAdditionController.handleAddMemeberTeams(acc.Id, new List<Team_Member__c>{actMember});
        test.stopTest();
    }
    
}