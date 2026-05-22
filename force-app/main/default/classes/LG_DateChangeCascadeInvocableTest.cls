@IsTest(SeeAllData = true)
private class LG_DateChangeCascadeInvocableTest {
    @IsTest
    static void testCascadeBasic() {
        ServiceContract sc = [
            SELECT Id, LG_Requested_Swim_Date__c
            FROM ServiceContract
            WHERE Name = 'Mecox Estate FY26 Annual'
            LIMIT 1
        ];

        LG_DateChangeCascadeInvocable.CascadeRequest req = new LG_DateChangeCascadeInvocable.CascadeRequest();
        req.serviceContractId = sc.Id;
        req.oldSwimDate = Date.newInstance(2026, 5, 6);
        req.newSwimDate = Date.newInstance(2026, 5, 20);

        Test.startTest();
        List<LG_DateChangeCascadeInvocable.CascadeResult> results = LG_DateChangeCascadeInvocable.cascade(
            new List<LG_DateChangeCascadeInvocable.CascadeRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result');
        System.assertEquals(true, results[0].success, 'Cascade failed: ' + results[0].message);
    }
}
