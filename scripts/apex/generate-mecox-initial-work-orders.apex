// Step 8b: Trigger Field Service batch Work Order generation for Mecox Maintenance Plan.
//
// Platform notes (this org):
// - MaintenancePlan.generateWorkOrders(Id) does NOT exist on MaintenancePlan in Apex.
// - Use standard REST action POST .../actions/standard/generateWorkOrders with body {"inputs":[{"recordId":"<planId>"}]}.
// - Manual generation returns INVALID_OPERATION while DoesAutoGenerateWorkOrders = true ("deselect auto-generate...").
// - Apex cannot perform DML and then an Http callout in the same transaction. This script therefore uses two steps in ONE file:
//   * Run 1: If auto-generate is on, we set it to false and return (no callout). Run the script again right away.
//   * Run 2: With auto-generate off and zero Mecox Work Orders, performs the callout only.
//
// After the REST action returns 200, generation may still be asynchronous. Wait ~10s, then run your verification SOQL.

Id mecoxAccountId = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1].Id;

Integer existingWos = [SELECT COUNT() FROM WorkOrder WHERE AccountId = :mecoxAccountId];
System.assertEquals(
    0,
    existingWos,
    'Abort: Mecox Account already has ' +
        existingWos +
        ' Work Order(s). Do not re-invoke generateWorkOrders (duplicates). Delete WOs first if intentional.'
);

MaintenancePlan mp = [
    SELECT Id, DoesAutoGenerateWorkOrders
    FROM MaintenancePlan
    WHERE MaintenancePlanTitle = 'Mecox Estate FY26 Maintenance Plan'
    LIMIT 1
];

if (mp.DoesAutoGenerateWorkOrders) {
    mp.DoesAutoGenerateWorkOrders = false;
    Database.update(new List<MaintenancePlan>{ mp }, true);
    System.debug(
        LoggingLevel.WARN,
        'STEP 1/2: DoesAutoGenerateWorkOrders set to false. Execute this same script again to POST generateWorkOrders (no DML in that run).'
    );
    return;
}

String base = Url.getOrgDomainUrl().toExternalForm();
String apiVersion = 'v59.0';
HttpRequest req = new HttpRequest();
req.setEndpoint(base + '/services/data/' + apiVersion + '/actions/standard/generateWorkOrders');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json;charset=UTF-8');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setBody('{"inputs":[{"recordId":"' + String.valueOf(mp.Id) + '"}]}');

try {
    HttpResponse res = new Http().send(req);
    System.debug('generateWorkOrders HTTP ' + res.getStatusCode());
    System.debug(res.getBody());
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        throw new CalloutException('Unexpected HTTP status: ' + res.getStatusCode() + ' ' + res.getBody());
    }
} catch (CalloutException e) {
    System.debug(LoggingLevel.ERROR, e.getMessage());
    throw e;
}

System.debug('STEP 2/2: generateWorkOrders accepted. Wait ~10s then query WorkOrder / ServiceAppointment / MaintenanceWorkRule.');
