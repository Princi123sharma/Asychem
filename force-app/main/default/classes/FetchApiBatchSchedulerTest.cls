@isTest
public class FetchApiBatchSchedulerTest {

    @isTest
    static void testExecute() {
        // Arrange
        String testTableName = 'SalesOrder';

        // Act
        Test.startTest();
        FetchApiBatchScheduler scheduler = new FetchApiBatchScheduler(testTableName); 
        scheduler.execute(null); // SchedulableContext is not used
        Test.stopTest();

        // Assert
        System.assertEquals(testTableName, scheduler.tableName, 'Table name should be set correctly');

        // Optional: You can add additional checks if your FetchApiBatch has some debug logs or internal effects
    }
}