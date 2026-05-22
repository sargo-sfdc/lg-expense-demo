@IsTest
private class LG_CreateFollowupWorkOrderInvocableTest {
    @IsTest
    static void createFollowUp_emptyList_throws() {
        try {
            LG_CreateFollowupWorkOrderInvocable.createFollowUp(new List<LG_CreateFollowupWorkOrderInvocable.Request>());
            System.assert(false, 'Expected InvocableException');
        } catch (LG_CreateFollowupWorkOrderInvocable.InvocableException e) {
            System.assert(e.getMessage().contains('Missing'), e.getMessage());
        }
    }

    @IsTest
    static void createFollowUp_blankRecordId_throws() {
        LG_CreateFollowupWorkOrderInvocable.Request req = new LG_CreateFollowupWorkOrderInvocable.Request();
        req.recordId = '  ';
        try {
            LG_CreateFollowupWorkOrderInvocable.createFollowUp(new List<LG_CreateFollowupWorkOrderInvocable.Request>{ req });
            System.assert(false, 'Expected InvocableException');
        } catch (LG_CreateFollowupWorkOrderInvocable.InvocableException e) {
            System.assert(e.getMessage().contains('Missing'), e.getMessage());
        }
    }

    @IsTest
    static void createFollowUp_invalidRecordId_throws() {
        LG_CreateFollowupWorkOrderInvocable.Request req = new LG_CreateFollowupWorkOrderInvocable.Request();
        req.recordId = 'not-an-id';
        try {
            LG_CreateFollowupWorkOrderInvocable.createFollowUp(new List<LG_CreateFollowupWorkOrderInvocable.Request>{ req });
            System.assert(false, 'Expected InvocableException');
        } catch (LG_CreateFollowupWorkOrderInvocable.InvocableException e) {
            System.assert(e.getMessage().contains('Invalid'), e.getMessage());
        }
    }
}
