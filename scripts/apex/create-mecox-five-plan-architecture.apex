// Step 8a-v2: Repurpose Plan 1 + create four one-rule MaintenancePlans for Mecox (five plans total).

Id accountId = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1].Id;
Id contractId = [SELECT Id FROM ServiceContract WHERE Name = 'Mecox Estate FY26 Annual' LIMIT 1].Id;

Map<String, Id> assetIdByName = new Map<String, Id>();
for (Asset a : [SELECT Id, Name FROM Asset WHERE AccountId = :accountId]) {
    assetIdByName.put(a.Name, a.Id);
}
Id poolAssetId = assetIdByName.get('Mecox Pool');
Id spaAssetId = assetIdByName.get('Mecox Spa');
Id fountainAssetId = assetIdByName.get('Mecox Fountain');
System.assertNotEquals(null, poolAssetId);
System.assertNotEquals(null, spaAssetId);
System.assertNotEquals(null, fountainAssetId);

Map<String, Id> workTypeIdByName = new Map<String, Id>();
for (WorkType wt : [
    SELECT Id, Name
    FROM WorkType
    WHERE Name IN ('Weekly Maintenance', 'Chem Check', 'Winter Maintenance')
]) {
    workTypeIdByName.put(wt.Name, wt.Id);
}
Id wtWeekly = workTypeIdByName.get('Weekly Maintenance');
Id wtChem = workTypeIdByName.get('Chem Check');
Id wtWinter = workTypeIdByName.get('Winter Maintenance');
System.assertNotEquals(null, wtWeekly);
System.assertNotEquals(null, wtChem);
System.assertNotEquals(null, wtWinter);

Set<String> newPlanTitles = new Set<String>{
    'Mecox Estate FY26 — Pool In-Season Chem Check',
    'Mecox Estate FY26 — Pool Off-Season Winter Maintenance',
    'Mecox Estate FY26 — Spa Weekly Maintenance',
    'Mecox Estate FY26 — Fountain Extended Season'
};
System.assertEquals(
    0,
    [SELECT COUNT() FROM MaintenancePlan WHERE MaintenancePlanTitle IN :newPlanTitles],
    'One or more target plans already exist; abort to avoid duplicates.'
);

MaintenancePlan plan1 = [
    SELECT
        Id,
        MaintenancePlanTitle,
        DoesAutoGenerateWorkOrders,
        AccountId,
        ServiceContractId,
        WorkTypeId,
        StartDate,
        EndDate,
        GenerationTimeframe,
        GenerationTimeframeType,
        WorkOrderGenerationMethod,
        DoesGenerateUponCompletion,
        NextSuggestedMaintenanceDate,
        Description
    FROM MaintenancePlan
    WHERE MaintenancePlanTitle = 'Mecox Estate FY26 Maintenance Plan'
    LIMIT 1
];
System.assertEquals(
    'Mecox Estate FY26 Maintenance Plan',
    plan1.MaintenancePlanTitle,
    'Repurpose only the rollback plan titled Mecox Estate FY26 Maintenance Plan.'
);

Date planStart = Date.newInstance(2026, 4, 1);
Date planEnd = Date.newInstance(2027, 3, 31);
Date placeholderNext = planStart;
Date winterNext = Date.newInstance(2026, 4, 28);

Savepoint sp = Database.setSavepoint();
try {
    // Phase 1: rename / confirm Plan 1
    plan1.MaintenancePlanTitle = 'Mecox Estate FY26 — Pool In-Season Weekly Maintenance';
    plan1.DoesAutoGenerateWorkOrders = false;
    Database.update(new List<MaintenancePlan>{ plan1 }, true);
    Id plan1Id = plan1.Id;

    // Phase 2: four new plans (Chem, Winter, Spa, Fountain)
    List<MaintenancePlan> newPlans = new List<MaintenancePlan>{
        new MaintenancePlan(
            MaintenancePlanTitle = 'Mecox Estate FY26 — Pool In-Season Chem Check',
            AccountId = accountId,
            ServiceContractId = contractId,
            StartDate = planStart,
            EndDate = planEnd,
            NextSuggestedMaintenanceDate = placeholderNext,
            GenerationTimeframe = 90,
            GenerationTimeframeType = 'Days',
            WorkOrderGenerationMethod = 'WorkOrderPerAsset',
            DoesGenerateUponCompletion = false,
            DoesAutoGenerateWorkOrders = false,
            WorkTypeId = wtChem,
            Description = 'Pool chem check, weekly Mondays in season. Active when Pool Open.'
        ),
        new MaintenancePlan(
            MaintenancePlanTitle = 'Mecox Estate FY26 — Pool Off-Season Winter Maintenance',
            AccountId = accountId,
            ServiceContractId = contractId,
            StartDate = planStart,
            EndDate = planEnd,
            NextSuggestedMaintenanceDate = winterNext,
            GenerationTimeframe = 90,
            GenerationTimeframeType = 'Days',
            WorkOrderGenerationMethod = 'WorkOrderPerAsset',
            DoesGenerateUponCompletion = false,
            DoesAutoGenerateWorkOrders = true,
            WorkTypeId = wtWinter,
            Description = 'Pool winter maintenance, biweekly Tuesdays off-season. Active when Pool Winterized.'
        ),
        new MaintenancePlan(
            MaintenancePlanTitle = 'Mecox Estate FY26 — Spa Weekly Maintenance',
            AccountId = accountId,
            ServiceContractId = contractId,
            StartDate = planStart,
            EndDate = planEnd,
            NextSuggestedMaintenanceDate = placeholderNext,
            GenerationTimeframe = 90,
            GenerationTimeframeType = 'Days',
            WorkOrderGenerationMethod = 'WorkOrderPerAsset',
            DoesGenerateUponCompletion = false,
            DoesAutoGenerateWorkOrders = false,
            WorkTypeId = wtWeekly,
            Description = 'Spa weekly service, Wednesdays in season. Active when Spa Open. Independent of Pool plan.'
        ),
        new MaintenancePlan(
            MaintenancePlanTitle = 'Mecox Estate FY26 — Fountain Extended Season',
            AccountId = accountId,
            ServiceContractId = contractId,
            StartDate = planStart,
            EndDate = planEnd,
            NextSuggestedMaintenanceDate = placeholderNext,
            GenerationTimeframe = 90,
            GenerationTimeframeType = 'Days',
            WorkOrderGenerationMethod = 'WorkOrderPerAsset',
            DoesGenerateUponCompletion = false,
            DoesAutoGenerateWorkOrders = false,
            WorkTypeId = wtWeekly,
            Description = 'Fountain weekly service, Thursdays. Active when Fountain Open. Runs through Dec 15.'
        )
    };
    Database.insert(newPlans, true);

    Id planChemId = newPlans[0].Id;
    Id planWinterId = newPlans[1].Id;
    Id planSpaId = newPlans[2].Id;
    Id planFountainId = newPlans[3].Id;

    // Phase 3: existing work rule on Plan 1
    MaintenanceWorkRule poolWeeklyRule = [
        SELECT Id, Title, SortOrder, Type, RecurrencePattern, NextSuggestedMaintenanceDate
        FROM MaintenanceWorkRule
        WHERE ParentMaintenancePlanId = :plan1Id
        LIMIT 1
    ];
    poolWeeklyRule.Title = 'Pool Weekly Maintenance';
    poolWeeklyRule.SortOrder = 1;
    poolWeeklyRule.Type = 'Calendar';
    Database.update(new List<MaintenanceWorkRule>{ poolWeeklyRule }, true);

    // Phase 4: one rule per new plan
    List<MaintenanceWorkRule> newRules = new List<MaintenanceWorkRule>{
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planChemId,
            Title = 'Pool Chem Check',
            Type = 'Calendar',
            SortOrder = 1,
            WorkTypeId = wtChem,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO',
            NextSuggestedMaintenanceDate = null
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planWinterId,
            Title = 'Pool Winter Maintenance',
            Type = 'Calendar',
            SortOrder = 1,
            WorkTypeId = wtWinter,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
            NextSuggestedMaintenanceDate = winterNext
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planSpaId,
            Title = 'Spa Weekly Maintenance',
            Type = 'Calendar',
            SortOrder = 1,
            WorkTypeId = wtWeekly,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=WE',
            NextSuggestedMaintenanceDate = null
        ),
        new MaintenanceWorkRule(
            ParentMaintenancePlanId = planFountainId,
            Title = 'Fountain Extended Season',
            Type = 'Calendar',
            SortOrder = 1,
            WorkTypeId = wtWeekly,
            RecurrencePattern = 'FREQ=WEEKLY;INTERVAL=1;BYDAY=TH',
            NextSuggestedMaintenanceDate = null
        )
    };
    Database.insert(newRules, true);

    // Platform may copy the plan next-batch date onto new calendar rules; clear in-season rules (do_not).
    Set<Id> allMecoxPlanIds = new Set<Id>{
        plan1Id,
        planChemId,
        planWinterId,
        planSpaId,
        planFountainId
    };
    List<MaintenanceWorkRule> clearNext = [
        SELECT Id, Title, NextSuggestedMaintenanceDate
        FROM MaintenanceWorkRule
        WHERE ParentMaintenancePlanId IN :allMecoxPlanIds AND Title != 'Pool Winter Maintenance'
    ];
    for (MaintenanceWorkRule r : clearNext) {
        r.NextSuggestedMaintenanceDate = null;
    }
    if (!clearNext.isEmpty()) {
        Database.update(clearNext, true);
    }

    // Phase 5: maintenance assets for plans 2–5
    List<MaintenanceAsset> newMas = new List<MaintenanceAsset>{
        new MaintenanceAsset(MaintenancePlanId = planChemId, AssetId = poolAssetId),
        new MaintenanceAsset(MaintenancePlanId = planWinterId, AssetId = poolAssetId),
        new MaintenanceAsset(MaintenancePlanId = planSpaId, AssetId = spaAssetId),
        new MaintenanceAsset(MaintenancePlanId = planFountainId, AssetId = fountainAssetId)
    };
    Database.insert(newMas, true);

    System.debug('Plan1=' + plan1Id);
    System.debug('PlanChem=' + planChemId + ' PlanWinter=' + planWinterId + ' PlanSpa=' + planSpaId + ' PlanFountain=' + planFountainId);
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
