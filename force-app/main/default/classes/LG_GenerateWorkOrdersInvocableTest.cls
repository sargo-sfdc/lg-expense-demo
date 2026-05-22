@IsTest
private class LG_GenerateWorkOrdersInvocableTest {
    private class MockGenerateResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"example":"ok"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private static MaintenancePlan createTestPlan(Boolean autoGen) {
        Account acc = new Account(Name = 'LG_GenerateWorkOrdersInvocable Test Account');
        insert acc;

        Date start = Date.today().addDays(-30);
        MaintenancePlan mp = new MaintenancePlan(
            AccountId = acc.Id,
            MaintenancePlanTitle = 'LG Unit Test Plan',
            StartDate = start,
            NextSuggestedMaintenanceDate = start.addDays(14),
            GenerationTimeframe = 12,
            GenerationTimeframeType = 'Months',
            DoesGenerateUponCompletion = false,
            DoesAutoGenerateWorkOrders = autoGen,
            Winter__c = false
        );
        insert mp;
        return mp;
    }

    @IsTest
    static void testGenerateWithValidPlanIds() {
        MaintenancePlan mp = createTestPlan(true);
        Test.setMock(HttpCalloutMock.class, new MockGenerateResponse());

        LG_GenerateWorkOrdersInvocable.GenerateRequest req = new LG_GenerateWorkOrdersInvocable.GenerateRequest();
        req.maintenancePlanIds = new List<Id>{ mp.Id };

        Test.startTest();
        List<LG_GenerateWorkOrdersInvocable.GenerateResult> results = LG_GenerateWorkOrdersInvocable.generate(
            new List<LG_GenerateWorkOrdersInvocable.GenerateRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one result');
        System.assertEquals(true, results[0].success, 'Expected success: ' + results[0].message);

        MaintenancePlan after = [
            SELECT Id, DoesAutoGenerateWorkOrders
            FROM MaintenancePlan
            WHERE Id = :mp.Id
        ][0];
        System.assertEquals(true, after.DoesAutoGenerateWorkOrders, 'Auto-generate should be restored to true');
    }

    @IsTest
    static void testGenerateWithEmptyInput() {
        LG_GenerateWorkOrdersInvocable.GenerateRequest req = new LG_GenerateWorkOrdersInvocable.GenerateRequest();
        req.maintenancePlanIds = new List<Id>();

        List<LG_GenerateWorkOrdersInvocable.GenerateResult> results = LG_GenerateWorkOrdersInvocable.generate(
            new List<LG_GenerateWorkOrdersInvocable.GenerateRequest>{ req }
        );

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testGenerateNoMatchingPlans() {
        LG_GenerateWorkOrdersInvocable.GenerateRequest req = new LG_GenerateWorkOrdersInvocable.GenerateRequest();
        Account wrong = new Account(Name = 'LG Wrong Type For MP');
        insert wrong;
        req.maintenancePlanIds = new List<Id>{ wrong.Id };

        List<LG_GenerateWorkOrdersInvocable.GenerateResult> results = LG_GenerateWorkOrdersInvocable.generate(
            new List<LG_GenerateWorkOrdersInvocable.GenerateRequest>{ req }
        );

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No Maintenance Plans found'));
    }
}
