// Step 8b-v2: Generate Winter Maintenance WOs for Mecox Pool via REST generateWorkOrders.
//
// Platform constraint (same as Step 8b-v1): the standard action returns INVALID_OPERATION while
// DoesAutoGenerateWorkOrders = true ("deselect auto-generate work orders" for manual generation).
// This script uses three anonymous runs in one file:
//   Run 1 — Phase A: set winter plan DoesAutoGenerateWorkOrders = false, then return.
//   Run 2 — Phase B: Http POST generateWorkOrders (no DML in this run before callout).
//   Run 3 — Phase C: after WOs exist, set DoesAutoGenerateWorkOrders = true again (demo state).
//
// Between Run 2 and Run 3, wait ~10–15s for async generation.

Id winterPlanId = '1MPfj000002AbWcGAK';

Id mecoxAccountId = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1].Id;
Integer allMecoxWoCount = [SELECT COUNT() FROM WorkOrder WHERE AccountId = :mecoxAccountId];
Integer winterPlanWoCount = [SELECT COUNT() FROM WorkOrder WHERE MaintenancePlanId = :winterPlanId];

MaintenancePlan winter = [
    SELECT
        Id,
        MaintenancePlanTitle,
        DoesAutoGenerateWorkOrders,
        NextSuggestedMaintenanceDate,
        GenerationTimeframe,
        WorkOrderGenerationStatus
    FROM MaintenancePlan
    WHERE Id = :winterPlanId
    LIMIT 1
];

System.assertEquals('Mecox Estate FY26 — Pool Off-Season Winter Maintenance', winter.MaintenancePlanTitle);
System.assertEquals(Date.newInstance(2026, 4, 28), winter.NextSuggestedMaintenanceDate);
System.assertEquals(90, winter.GenerationTimeframe);

Integer otherAutoOn = [
    SELECT COUNT()
    FROM MaintenancePlan
    WHERE MaintenancePlanTitle LIKE 'Mecox Estate FY26%' AND Id != :winterPlanId AND DoesAutoGenerateWorkOrders = true
];
System.assertEquals(0, otherAutoOn, 'Only the winter plan may have DoesAutoGenerateWorkOrders = true before Phase A.');

// Idempotent: generation already done and autogen restored
if (winter.DoesAutoGenerateWorkOrders && winterPlanWoCount >= 1) {
    System.debug(
        'No action: winter plan already has DoesAutoGenerateWorkOrders=true and ' +
            winterPlanWoCount +
            ' Work Order(s) on this plan.'
    );
    return;
}

// Phase C: restore autogen after generation (run after ~10–15s when winterPlanWoCount >= 1)
if (!winter.DoesAutoGenerateWorkOrders && winterPlanWoCount >= 1) {
    winter.DoesAutoGenerateWorkOrders = true;
    Database.update(new List<MaintenancePlan>{ winter }, true);
    System.debug(
        'Phase C: Restored DoesAutoGenerateWorkOrders=true on winter plan (WO count on plan=' +
            winterPlanWoCount +
            ').'
    );
    return;
}

// Phase A: allow REST by turning autogen off (re-run for Phase B)
if (winter.DoesAutoGenerateWorkOrders && allMecoxWoCount == 0) {
    winter.DoesAutoGenerateWorkOrders = false;
    Database.update(new List<MaintenancePlan>{ winter }, true);
    System.debug(
        'Phase A: DoesAutoGenerateWorkOrders set false on winter plan (Salesforce REST requirement). Re-run this script for Phase B.'
    );
    return;
}

// Phase B: callout only (no prior DML in this execution)
if (!winter.DoesAutoGenerateWorkOrders && allMecoxWoCount == 0) {
    if (winter.WorkOrderGenerationStatus == 'InProgress') {
        System.debug('Phase B: Work order generation already in progress; wait and re-check.');
        return;
    }

    String base = Url.getOrgDomainUrl().toExternalForm();
    String apiVersion = 'v59.0';
    HttpRequest req = new HttpRequest();
    req.setEndpoint(base + '/services/data/' + apiVersion + '/actions/standard/generateWorkOrders');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json;charset=UTF-8');
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setBody('{"inputs":[{"recordId":"' + String.valueOf(winterPlanId) + '"}]}');

    HttpResponse res = new Http().send(req);
    System.debug('generateWorkOrders HTTP ' + res.getStatusCode());
    System.debug(res.getBody());
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        throw new CalloutException('Unexpected status: ' + res.getStatusCode() + ' ' + res.getBody());
    }
    System.debug(
        'Phase B: generateWorkOrders accepted. Wait ~10–15s, verify 7 Winter WOs, then re-run this script for Phase C (restore autogen).'
    );
    return;
}

System.assert(
    false,
    'Unexpected state: allMecoxWoCount=' +
        allMecoxWoCount +
        ', winterPlanWoCount=' +
        winterPlanWoCount +
        ', DoesAutoGenerateWorkOrders=' +
        winter.DoesAutoGenerateWorkOrders
);
