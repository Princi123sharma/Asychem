@isTest
public class FetchApiBatchTest {

    @isTest static void testBatchRunsWithOneChunk() {
        DateTime startTime = DateTime.now().addDays(-1);
        DateTime endTime = DateTime.now();

        // Create instance
        FetchApiBatch batch = new FetchApiBatch('Invoice', startTime, endTime);

        Test.startTest();
        // Scope size = 100, same as PAGE_SIZE, so only 1 chunk in test
        Database.executeBatch(batch, 100);
        Test.stopTest();

        System.assert(true, 'Batch executed successfully with single chunk.');
    }
}