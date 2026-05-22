// Roll back failed Step 8b: delete Mecox WOs/SAs, trim plan to Pool weekly rule + Pool MA only,
// clear NextSuggested on kept rule, leave DoesAutoGenerateWorkOrders = false for 8a-v2 gap.

Savepoint sp = Database.setSavepoint();
try {
    Id mecoxAccountId = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1].Id;

    Set<Id> woIds = new Map<Id, WorkOrder>([
        SELECT Id
        FROM WorkOrder
        WHERE AccountId = :mecoxAccountId
    ])
        .keySet();

    if (!woIds.isEmpty()) {
        List<ServiceAppointment> sas = [
            SELECT Id
            FROM ServiceAppointment
            WHERE ParentRecordId IN :woIds
        ];
        if (!sas.isEmpty()) {
            Database.delete(sas, true);
        }
        List<WorkOrder> wos = [SELECT Id FROM WorkOrder WHERE Id IN :woIds];
        Database.delete(wos, true);
    }

    Id planId = [
        SELECT Id
        FROM MaintenancePlan
        WHERE MaintenancePlanTitle = 'Mecox Estate FY26 Maintenance Plan'
        LIMIT 1
    ]
        .Id;

    List<MaintenanceWorkRule> rulesToDelete = [
        SELECT Id
        FROM MaintenanceWorkRule
        WHERE ParentMaintenancePlanId = :planId AND Title != 'Mecox — Weekly Maintenance'
    ];
    if (!rulesToDelete.isEmpty()) {
        Database.delete(rulesToDelete, true);
    }

    List<MaintenanceAsset> mAssetsToDelete = [
        SELECT Id
        FROM MaintenanceAsset
        WHERE MaintenancePlanId = :planId AND Asset.Name != 'Mecox Pool'
    ];
    if (!mAssetsToDelete.isEmpty()) {
        Database.delete(mAssetsToDelete, true);
    }

    MaintenanceWorkRule poolWeekly = [
        SELECT Id, NextSuggestedMaintenanceDate
        FROM MaintenanceWorkRule
        WHERE ParentMaintenancePlanId = :planId AND Title = 'Mecox — Weekly Maintenance'
        LIMIT 1
    ];
    poolWeekly.NextSuggestedMaintenanceDate = null;
    Database.update(new List<MaintenanceWorkRule>{ poolWeekly }, true);

    MaintenancePlan plan = [
        SELECT Id, DoesAutoGenerateWorkOrders
        FROM MaintenancePlan
        WHERE Id = :planId
        LIMIT 1
    ];
    plan.DoesAutoGenerateWorkOrders = false;
    Database.update(new List<MaintenancePlan>{ plan }, true);

    System.debug('Rollback complete. PlanId=' + planId);
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
