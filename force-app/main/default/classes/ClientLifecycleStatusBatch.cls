public with sharing class ClientLifecycleStatusBatch implements Database.Batchable<SObject>, Schedulable {
    private Id accountId;

    public ClientLifecycleStatusBatch() {
    }

    public ClientLifecycleStatusBatch(Id accountId) {
        this.accountId = accountId;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (accountId != null) {
            return Database.getQueryLocator([
                SELECT
                    Id,
                    CreatedDate,
                    Client_Status__c,
                    BD_Departure_Date__c,
                    OwnerId,
                    Pending_Reason__c,
                    Pending_Reason_Status__c,
                    Pending_Reason_Submitted_By__c,
                    Pending_Reason_Submitted_Date__c,
                    Pending_Reason_Approver__c,
                    Pending_Reason_Decision_Date__c,
                    Pending_Start_Date__c,
                    Pending_Response_Due_Date__c
                FROM Account
                WHERE Id = :accountId
            ]);
        }

        return Database.getQueryLocator([
            SELECT
                Id,
                CreatedDate,
                Client_Status__c,
                BD_Departure_Date__c,
                OwnerId,
                Pending_Reason__c,
                Pending_Reason_Status__c,
                Pending_Reason_Submitted_By__c,
                Pending_Reason_Submitted_Date__c,
                Pending_Reason_Approver__c,
                Pending_Reason_Decision_Date__c,
                Pending_Start_Date__c,
                Pending_Response_Due_Date__c
            FROM Account
        ]);
    }

    public void execute(Database.BatchableContext context, List<Account> accounts) {
        if (accounts.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Account accountRecord : accounts) {
            accountIds.add(accountRecord.Id);
        }

        Date today = Date.today();
        Date sixMonthsAgo = today.addMonths(-6);
        Date twelveMonthsAgo = today.addMonths(-12);
        Date eighteenMonthsAgo = today.addMonths(-18);
        Date oneMonthAgo = today.addMonths(-1);

        Map<Id, Date> accountCreatedDates = getAccountCreatedDates(accounts);
        Map<Id, List<Date>> poDatesByAccountId = getPoDatesByAccount(accountIds);
        Map<Id, Date> latestPoDates = getLatestPoDates(poDatesByAccountId);
        Map<Id, RfpActivity> latestRfpActivities = getLatestRfpActivities(accountIds);
        Map<Id, Date> latestRfpDates = getRfpActivityDates(latestRfpActivities);
        Set<Id> accountsWithPoForLatestRfp = getAccountsWithPoForLatestRfpActivity(latestRfpActivities);
        Map<Id, QuoteActivity> latestQuoteActivities = getLatestQuoteActivities(accountIds);
        Set<Id> accountsWithQuoteActivity = new Set<Id>(latestQuoteActivities.keySet());
        Map<Id, Date> latestQuotedRfpDates = getLatestQuoteDates(latestQuoteActivities);
        Set<Id> accountsWithPoForLatestQuote = getAccountsWithPoForLatestQuote(latestQuoteActivities);
        Map<Id, RfpActivity> latestNewRfpActivitiesAfterPo =
            getLatestNewRfpActivitiesAfterPo(accountIds, poDatesByAccountId);
        Map<Id, Date> latestNewRfpActivityDatesAfterPo =
            getRfpActivityDates(latestNewRfpActivitiesAfterPo);
        Set<Id> accountsWithPoForLatestNewRfpActivityAfterPo =
            getAccountsWithPoForLatestRfpActivity(latestNewRfpActivitiesAfterPo);
        Set<Id> accountsOwnedByDepartedBds = getAccountsOwnedByDepartedBds(accounts, oneMonthAgo);

        List<Account> accountsToUpdate = new List<Account>();
        for (Account accountRecord : accounts) {
            String lifecycleStatus = evaluateStatus(
                accountRecord.Id,
                accountCreatedDates,
                latestRfpDates,
                accountsWithPoForLatestRfp,
                accountsWithQuoteActivity,
                latestQuotedRfpDates,
                accountsWithPoForLatestQuote,
                latestPoDates,
                latestNewRfpActivityDatesAfterPo,
                accountsWithPoForLatestNewRfpActivityAfterPo,
                accountsOwnedByDepartedBds,
                sixMonthsAgo,
                twelveMonthsAgo,
                eighteenMonthsAgo
            );
            String newStatus = lifecycleStatus;
            if (lifecycleStatus == 'Pending' && isPendingNoActionExpired(accountRecord, today)) {
                newStatus = 'Inactive';
            }

            Account accountToUpdate = new Account(Id = accountRecord.Id);
            Boolean hasUpdates = false;

            if (accountRecord.Client_Status__c != newStatus) {
                accountToUpdate.Client_Status__c = newStatus;
                hasUpdates = true;
            }

            if (shouldStartPendingCycle(accountRecord, newStatus)) {
                applyNewPendingCycleValues(accountToUpdate, today);
                hasUpdates = true;
            }

            if (hasUpdates) {
                accountsToUpdate.add(accountToUpdate);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate, false);
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new ClientLifecycleStatusBatch(), 200);
    }

    public static String scheduleMonthly() {
        return System.schedule(
            'Client Lifecycle Status Monthly',
            '0 0 2 1 * ?',
            new ClientLifecycleStatusBatch()
        );
    }

    @TestVisible
    private static String evaluateStatus(
        Id accountId,
        Map<Id, Date> accountCreatedDates,
        Map<Id, Date> latestRfpDates,
        Set<Id> accountsWithPoForLatestRfp,
        Set<Id> accountsWithQuoteActivity,
        Map<Id, Date> latestQuotedRfpDates,
        Set<Id> accountsWithPoForLatestQuote,
        Map<Id, Date> latestPoDates,
        Map<Id, Date> latestNewRfpActivityDatesAfterPo,
        Set<Id> accountsWithPoForLatestNewRfpActivityAfterPo,
        Set<Id> accountsOwnedByDepartedBds,
        Date sixMonthsAgo,
        Date twelveMonthsAgo,
        Date eighteenMonthsAgo
    ) {
        Date accountCreatedDate = accountCreatedDates.get(accountId);
        Date latestRfpDate = latestRfpDates.get(accountId);
        Date latestQuotedRfpDate = latestQuotedRfpDates.get(accountId);
        Date latestPoDate = latestPoDates.get(accountId);
        Date latestNewRfpActivityDateAfterPo = latestNewRfpActivityDatesAfterPo.get(accountId);

        if (accountsOwnedByDepartedBds.contains(accountId)) {
            return 'Inactive';
        }

        if (accountCreatedDate != null && accountCreatedDate <= sixMonthsAgo && latestRfpDate == null) {
            return 'Inactive';
        }

        if (latestQuotedRfpDate != null && !accountsWithPoForLatestQuote.contains(accountId)) {
            Boolean noRfpAfterLastQuote = latestRfpDate == null || latestRfpDate <= latestQuotedRfpDate;
            if (latestQuotedRfpDate <= twelveMonthsAgo && noRfpAfterLastQuote) {
                return 'Pending';
            }
        }

        if (
            latestQuotedRfpDate == null &&
            !accountsWithQuoteActivity.contains(accountId) &&
            latestRfpDate != null &&
            latestRfpDate <= twelveMonthsAgo &&
            !accountsWithPoForLatestRfp.contains(accountId)
        ) {
            return 'Pending';
        }

        if (
            latestNewRfpActivityDateAfterPo != null &&
            latestNewRfpActivityDateAfterPo <= eighteenMonthsAgo &&
            !accountsWithPoForLatestNewRfpActivityAfterPo.contains(accountId)
        ) {
            return 'Pending';
        }

        if (latestPoDate != null) {
            Date latestPostPoActivityDate = latestPoDate;
            if (latestRfpDate != null && latestRfpDate > latestPostPoActivityDate) {
                latestPostPoActivityDate = latestRfpDate;
            }

            if (latestPostPoActivityDate <= eighteenMonthsAgo) {
                return 'Pending';
            }
        }

        return 'Active';
    }

    private static Boolean isPendingNoActionExpired(Account accountRecord, Date today) {
        return accountRecord.Pending_Reason_Status__c == 'No Action' &&
            accountRecord.Pending_Response_Due_Date__c != null &&
            accountRecord.Pending_Response_Due_Date__c <= today;
    }

    private static Boolean shouldStartPendingCycle(Account accountRecord, String newStatus) {
        if (newStatus != 'Pending') {
            return false;
        }
        return accountRecord.Client_Status__c != 'Pending' ||
            String.isBlank(accountRecord.Pending_Reason_Status__c) ||
            accountRecord.Pending_Start_Date__c == null ||
            accountRecord.Pending_Response_Due_Date__c == null;
    }

    private static void applyNewPendingCycleValues(Account accountToUpdate, Date today) {
        accountToUpdate.Pending_Start_Date__c = today;
        accountToUpdate.Pending_Response_Due_Date__c = today.addMonths(1);
        accountToUpdate.Pending_Reason_Status__c = 'No Action';
        accountToUpdate.Pending_Reason__c = null;
        accountToUpdate.Pending_Reason_Submitted_By__c = null;
        accountToUpdate.Pending_Reason_Submitted_Date__c = null;
        accountToUpdate.Pending_Reason_Approver__c = null;
        accountToUpdate.Pending_Reason_Decision_Date__c = null;
    }

    private static Map<Id, Date> getAccountCreatedDates(List<Account> accounts) {
        Map<Id, Date> result = new Map<Id, Date>();
        for (Account accountRecord : accounts) {
            if (accountRecord.CreatedDate != null) {
                result.put(accountRecord.Id, accountRecord.CreatedDate.date());
            }
        }
        return result;
    }

    private static Map<Id, RfpActivity> getLatestRfpActivities(Set<Id> accountIds) {
        Map<Id, RfpActivity> result = new Map<Id, RfpActivity>();
        for (Opportunity opportunityRecord : [
            SELECT AccountId, Date_RFP_due_to_Client__c, StageName, Client_PO__c, CloseDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND Date_RFP_due_to_Client__c != null
        ]) {
            putLatestRfpActivity(result, opportunityRecord.AccountId, new RfpActivity(
                opportunityRecord.Date_RFP_due_to_Client__c,
                opportunityHasPo(opportunityRecord)
            ));
        }
        return result;
    }

    private static Map<Id, QuoteActivity> getLatestQuoteActivities(Set<Id> accountIds) {
        Map<Id, QuoteActivity> result = new Map<Id, QuoteActivity>();
        for (Quote quoteRecord : [
            SELECT
                Opportunity.AccountId,
                Opportunity.StageName,
                Opportunity.Client_PO__c,
                Opportunity.CloseDate,
                Status,
                Quote_due_to_Client__c,
                CreatedDate
            FROM Quote
            WHERE Opportunity.AccountId IN :accountIds
        ]) {
            Id accountId = quoteRecord.Opportunity.AccountId;
            Date quoteDate = quoteRecord.Quote_due_to_Client__c != null
                ? quoteRecord.Quote_due_to_Client__c
                : quoteRecord.CreatedDate.date();
            Boolean parentOpportunityHasPo =
                isSuccessfulPoStage(quoteRecord.Opportunity.StageName) &&
                String.isNotBlank(quoteRecord.Opportunity.Client_PO__c) &&
                quoteRecord.Opportunity.CloseDate != null;
            QuoteActivity currentActivity = result.get(accountId);
            if (currentActivity == null || quoteDate > currentActivity.quoteDate) {
                result.put(accountId, new QuoteActivity(
                    quoteRecord.Status,
                    quoteDate,
                    parentOpportunityHasPo
                ));
            }
        }
        return result;
    }

    private static Map<Id, Date> getLatestQuoteDates(Map<Id, QuoteActivity> latestQuoteActivities) {
        Map<Id, Date> quoteDatesByAccountId = new Map<Id, Date>();
        for (Id accountId : latestQuoteActivities.keySet()) {
            QuoteActivity activity = latestQuoteActivities.get(accountId);
            quoteDatesByAccountId.put(accountId, activity.quoteDate);
        }
        return quoteDatesByAccountId;
    }

    private static Set<Id> getAccountsWithPoForLatestQuote(Map<Id, QuoteActivity> latestQuoteActivities) {
        Set<Id> accountIds = new Set<Id>();
        for (Id accountId : latestQuoteActivities.keySet()) {
            QuoteActivity activity = latestQuoteActivities.get(accountId);
            if (activity.parentOpportunityHasPo) {
                accountIds.add(accountId);
            }
        }
        return accountIds;
    }

    private static Map<Id, List<Date>> getPoDatesByAccount(Set<Id> accountIds) {
        Map<Id, List<Date>> result = new Map<Id, List<Date>>();
        for (Opportunity opportunityRecord : [
            SELECT AccountId, CloseDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND StageName IN ('Closed Won', 'Closed Completed')
            AND Client_PO__c != null
            AND CloseDate != null
        ]) {
            if (!result.containsKey(opportunityRecord.AccountId)) {
                result.put(opportunityRecord.AccountId, new List<Date>());
            }
            result.get(opportunityRecord.AccountId).add(opportunityRecord.CloseDate);
        }
        return result;
    }

    private static Map<Id, Date> getLatestPoDates(Map<Id, List<Date>> poDatesByAccountId) {
        Map<Id, Date> result = new Map<Id, Date>();
        for (Id accountId : poDatesByAccountId.keySet()) {
            for (Date poDate : poDatesByAccountId.get(accountId)) {
                setLatestDate(result, accountId, poDate);
            }
        }
        return result;
    }

    private static Map<Id, RfpActivity> getLatestNewRfpActivitiesAfterPo(
        Set<Id> accountIds,
        Map<Id, List<Date>> poDatesByAccountId
    ) {
        Map<Id, RfpActivity> result = new Map<Id, RfpActivity>();
        for (Opportunity opportunityRecord : [
            SELECT AccountId, Date_RFP_due_to_Client__c, StageName, Client_PO__c, CloseDate
            FROM Opportunity
            WHERE AccountId IN :accountIds
            AND Date_RFP_due_to_Client__c != null
        ]) {
            Date rfpDate = opportunityRecord.Date_RFP_due_to_Client__c;
            if (hasPoBefore(poDatesByAccountId.get(opportunityRecord.AccountId), rfpDate)) {
                putLatestRfpActivity(result, opportunityRecord.AccountId, new RfpActivity(
                    rfpDate,
                    opportunityHasPo(opportunityRecord)
                ));
            }
        }

        return result;
    }

    private static Map<Id, Date> getRfpActivityDates(Map<Id, RfpActivity> rfpActivitiesByAccountId) {
        Map<Id, Date> result = new Map<Id, Date>();
        for (Id accountId : rfpActivitiesByAccountId.keySet()) {
            result.put(accountId, rfpActivitiesByAccountId.get(accountId).activityDate);
        }
        return result;
    }

    private static Set<Id> getAccountsWithPoForLatestRfpActivity(
        Map<Id, RfpActivity> rfpActivitiesByAccountId
    ) {
        Set<Id> result = new Set<Id>();
        for (Id accountId : rfpActivitiesByAccountId.keySet()) {
            if (rfpActivitiesByAccountId.get(accountId).parentOpportunityHasPo) {
                result.add(accountId);
            }
        }
        return result;
    }

    private static void putLatestRfpActivity(
        Map<Id, RfpActivity> rfpActivitiesByAccountId,
        Id accountId,
        RfpActivity candidateActivity
    ) {
        RfpActivity currentActivity = rfpActivitiesByAccountId.get(accountId);
        if (currentActivity == null || candidateActivity.activityDate > currentActivity.activityDate) {
            rfpActivitiesByAccountId.put(accountId, candidateActivity);
        }
    }

    private static Boolean hasPoBefore(List<Date> poDates, Date activityDate) {
        if (poDates == null || activityDate == null) {
            return false;
        }
        for (Date poDate : poDates) {
            if (poDate < activityDate) {
                return true;
            }
        }
        return false;
    }

    private static Boolean opportunityHasPo(Opportunity opportunityRecord) {
        return isSuccessfulPoStage(opportunityRecord.StageName) &&
            String.isNotBlank(opportunityRecord.Client_PO__c) &&
            opportunityRecord.CloseDate != null;
    }

    private static Boolean isSuccessfulPoStage(String stageName) {
        return stageName == 'Closed Won' || stageName == 'Closed Completed';
    }

    private static void setLatestDate(Map<Id, Date> valuesByAccountId, Id accountId, Date candidateDate) {
        if (accountId == null || candidateDate == null) {
            return;
        }
        Date currentDate = valuesByAccountId.get(accountId);
        if (currentDate == null || candidateDate > currentDate) {
            valuesByAccountId.put(accountId, candidateDate);
        }
    }

    private static Set<Id> getAccountsOwnedByDepartedBds(List<Account> accounts, Date oneMonthAgo) {
        Set<Id> ownerIds = new Set<Id>();
        for (Account accountRecord : accounts) {
            if (accountRecord.OwnerId != null) {
                ownerIds.add(accountRecord.OwnerId);
            }
        }

        Set<Id> inactiveOwnerIds = new Set<Id>();
        for (User ownerRecord : [
            SELECT Id
            FROM User
            WHERE Id IN :ownerIds
            AND IsActive = false
        ]) {
            inactiveOwnerIds.add(ownerRecord.Id);
        }

        Set<Id> accountIds = new Set<Id>();
        for (Account accountRecord : accounts) {
            if (
                accountRecord.BD_Departure_Date__c != null &&
                accountRecord.BD_Departure_Date__c <= oneMonthAgo &&
                inactiveOwnerIds.contains(accountRecord.OwnerId)
            ) {
                accountIds.add(accountRecord.Id);
            }
        }

        return accountIds;
    }

    private class QuoteActivity {
        private String status;
        private Date quoteDate;
        private Boolean parentOpportunityHasPo;

        private QuoteActivity(String status, Date quoteDate, Boolean parentOpportunityHasPo) {
            this.status = status;
            this.quoteDate = quoteDate;
            this.parentOpportunityHasPo = parentOpportunityHasPo;
        }
    }

    private class RfpActivity {
        private Date activityDate;
        private Boolean parentOpportunityHasPo;

        private RfpActivity(Date activityDate, Boolean parentOpportunityHasPo) {
            this.activityDate = activityDate;
            this.parentOpportunityHasPo = parentOpportunityHasPo;
        }
    }
}