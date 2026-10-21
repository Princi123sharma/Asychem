@IsTest
private class SharePointDeletionSyncSchedulerTest {
    @IsTest
    static void enqueuesTheDeletionSynchronizationJob() {
        Integer jobsBefore = Limits.getQueueableJobs();
        new SharePointDeletionSyncScheduler().execute(null);
        System.assertEquals(jobsBefore + 1, Limits.getQueueableJobs());
    }
}
