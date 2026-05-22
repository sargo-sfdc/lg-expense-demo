// Step 8a: Mecox Estate Maintenance Plan + MaintenanceAssets + MaintenanceWorkRules.
//
// Org schema notes (sfs-demo-org describe):
// - MaintenancePlan uses MaintenancePlanTitle (no Name). Queries must use MaintenancePlanTitle.
// - WorkOrderGenerationMethod picklist: WorkOrderPerAsset | WorkOrderLineItemPerAsset (not WithoutCompletion).
//   Fixed calendar vs "after completion" is controlled by DoesGenerateUponCompletion = false on the plan.
// - MaintenanceWorkRule: ParentMaintenancePlanId (not MaintenancePlanId); Type = Calendar | CriteriaValue;
//   no RecurrenceStartDate / IsActive — use RecurrencePattern (RRULE) + NextSuggestedMaintenanceDate.
//   Inactive demo rules: NextSuggestedMaintenanceDate = null until Step 9 Flow sets them.
//   Active Winter rule: NextSuggestedMaintenanceDate = first anchor date (2025-11-04).

System.assertEquals(
    0,
    [SELECT COUNT() FROM MaintenancePlan WHERE MaintenancePlanTitle = 'Mecox Estate FY26 Maintenance Plan'],
    'Maintenance plan already exists'
);

Account mecox = [
    SELECT Id
    FROM Account
    WHERE Name = 'Mecox Estate'
    LIMIT 1
];
ServiceContract sc = [
    SELECT Id
    FROM ServiceContract
    WHERE Name = 'Mecox Estate FY26 Annual'
    LIMIT 1
];
Map<String, Id> assetIdByName = new Map<String, Id>();
for (Asset a : [
    SELECT Id, Name
    FROM Asset
    WHERE AccountId = :mecox.Id
    ORDER BY Name
]) {
    assetIdByName.put(a.Name, a.Id);
}
System.assert(assetIdByName.containsKey('Mecox Pool'), 'Mecox Pool asset missing');
System.assert(assetIdByName.containsKey('Mecox Spa'), 'Mecox Spa asset missing');
System.assert(assetIdByName.containsKey('Mecox Fountain'), 'Mecox Fountain asset missing');

Map<String, Id> workTypeIdByName = new Map<String, Id>();
for (WorkType wt : [
    SELECT Id, Name
    FROM WorkType
    WHERE Name IN ('Weekly Maintenance', 'Chem Check', 'Winter Maintenance')
]) {
    workTypeIdByName.put(wt.Name, wt.Id);
}
System.assertEquals(3, workTypeIdByName.size());

Id wtWeekly = workTypeIdByName.get('Weekly Maintenance');
Id wtChem = workTypeIdByName.get('Chem Check');
Id wtWinter = workTypeIdByName.get('Winter Maintenance');

Date planStart = Date.newInstance(2026, 4, 1);
Date planEnd = Date.newInstance(2027, 3, 31);

Savepoint sp = Database.setSavepoint();
try {
    MaintenancePlan mp = new MaintenancePlan(
        MaintenancePlanTitle = 'Mecox Estate FY26 Maintenance Plan',
        AccountId = mecox.Id,
        ServiceContractId = sc.Id,
        StartDate = planStart,
        EndDate = planEnd,
        NextSuggestedMaintenanceDate = planStart,
        GenerationTimeframe = 90,
        GenerationTimeframeType = 'Days',
        WorkOrderGenerationMethod = 'WorkOrderPerAsset',
        DoesGenerateUponCompletion = false,
        DoesAutoGenerateWorkOrders = true,
        WorkTypeId = wtWeekly,
        Description = 'Annual maintenance plan covering Pool, Spa, Fountain. Four rules: in-season weekly + chem (toggle on Pool open), off-season winter maintenance (toggle on Pool winterized), fountain extended-season.'
    );
    Database.insert(new List<MaintenancePlan>{ mp }, true);
    Id planId = mp.Id;

    List<MaintenanceAsset> mas = new List<MaintenanceAsset>{
        new MaintenanceAsset(MaintenancePlanId = planId, AssetId = assetIdByName.get('Mecox Pool')),
        new MaintenanceAsset(MaintenancePlanId = planId, AssetId = assetIdByName.get('Mecox Spa')),
        new MaintenanceAsset(MaintenancePlanId = planId, AssetId = assetIdByName.get('Mecox Fountain'))
    };
    Database.insert(mas, true);

    Date winterAnchor = Date.newInstance(2025, 11, 4);

    List<MaintenanceWorkRule> rules = new List<MaintenanceWorkRule>{
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planId,
            Title = 'Mecox — Weekly Maintenance',
            Type = 'Calendar',
            SortOrder = 10,
            WorkTypeId = wtWeekly,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=WE',
            NextSuggestedMaintenanceDate = null
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planId,
            Title = 'Mecox — Chem Check',
            Type = 'Calendar',
            SortOrder = 20,
            WorkTypeId = wtChem,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO',
            NextSuggestedMaintenanceDate = null
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planId,
            Title = 'Mecox — Winter Maintenance',
            Type = 'Calendar',
            SortOrder = 30,
            WorkTypeId = wtWinter,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
            NextSuggestedMaintenanceDate = winterAnchor
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planId,
            Title = 'Mecox — Fountain Extended Season',
            Type = 'Calendar',
            SortOrder = 40,
            WorkTypeId = wtWeekly,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=TH',
            NextSuggestedMaintenanceDate = null
        )
    };
    Database.insert(rules, true);

    // After insert, the platform may copy the plan's next-batch date onto calendar rules.
    // Clear next dates on in-season rules so only Winter Maintenance schedules until Step 9 Flow runs.
    List<MaintenanceWorkRule> clearNext = [
        SELECT Id, Title, NextSuggestedMaintenanceDate
        FROM MaintenanceWorkRule
        WHERE ParentMaintenancePlanId = :planId AND Title != 'Mecox — Winter Maintenance'
    ];
    for (MaintenanceWorkRule r : clearNext) {
        r.NextSuggestedMaintenanceDate = null;
    }
    if (!clearNext.isEmpty()) {
        Database.update(clearNext, true);
    }

    System.debug('MaintenancePlanId=' + planId);
    for (MaintenanceAsset ma : mas) {
        System.debug('MaintenanceAsset Id=' + ma.Id + ' AssetId=' + ma.AssetId);
    }
    for (MaintenanceWorkRule r : rules) {
        System.debug(
            'MaintenanceWorkRule Id=' +
                r.Id +
                ' Title=' +
                r.Title +
                ' NextSuggestedMaintenanceDate=' +
                r.NextSuggestedMaintenanceDate
        );
    }
} catch (DmlException e) {
    Database.rollback(sp);
    for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug(
            LoggingLevel.ERROR,
            'DML ' +
                i +
                ': ' +
                e.getDmlMessage(i) +
                ' fields=' +
                e.getDmlFieldNames(i)
        );
    }
    throw e;
}
