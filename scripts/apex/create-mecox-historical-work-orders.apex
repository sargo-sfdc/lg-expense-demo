// Step 8c: Four completed historical Winter Maintenance Work Orders + Service Appointments for Mecox Pool
// (Mar 3, 17, 31 and Apr 14, 2026). Brian assigned. SA.Status = Completed; WO.Status = Closed (terminal picklist value).
//
// Org validation blocks SA when no territory member is effective for the appointment window. Brian's STM for
// South Fork - West may start mid-2026 (from demo setup); this script moves that EffectiveStartDate back to
// cover historical March/April 2026 visits before inserting appointments.
//
// Auto-created SA from Winter WorkType hits the same rule; this script inserts WO with a no-auto-SA WorkType
// (Upgrade), inserts SAs manually, then sets WO.WorkTypeId to Winter Maintenance and links the maintenance plan.
//
// WorkOrder.IsGeneratedFromMaintenancePlan is not writeable in this org — value is platform-controlled when MaintenancePlanId is set.
//
// Picklists (sfs-demo-org): WorkOrder.Status includes Completed and Closed; ServiceAppointment.Status includes Completed.
// Run: sf apex run -f scripts/apex/create-mecox-historical-work-orders.apex --target-org sfs-demo-org

Savepoint sp = Database.setSavepoint();
try {
    Id mecoxAccountId = '001fj00001A6meoAAB';
    Id mecoxPoolAssetId = '02ifj0000020aDdAAI';
    Id poolWinterPlanId = '1MPfj000002AbWcGAK';
    Id mecoxFY26ContractId = '810fj0000BLDMnNAQX';
    Id winterMaintenanceWorkTypeId = '08qfj0000003fBZAAY';
    Id placeholderWorkTypeId = '08qfj00000031NsAAI';
    Id brianResourceId = '0Hnfj0000004KV5CAM';
    Id southForkWestTerritoryId = '0Hhfj000000SVKECA4';

    List<String> subjects = new List<String>{
        'Maintenance Mecox Pool: March 3, 2026',
        'Maintenance Mecox Pool: March 17, 2026',
        'Maintenance Mecox Pool: March 31, 2026',
        'Maintenance Mecox Pool: April 14, 2026'
    };

    List<WorkOrder> existing = [
        SELECT Id
        FROM WorkOrder
        WHERE AccountId = :mecoxAccountId AND AssetId = :mecoxPoolAssetId AND Subject IN :subjects
    ];
    System.assert(existing.isEmpty(), 'Historical Work Orders with these subjects already exist: ' + existing);

    List<ServiceTerritoryMember> brianWestMembers = [
        SELECT Id, EffectiveStartDate
        FROM ServiceTerritoryMember
        WHERE ServiceResourceId = :brianResourceId AND ServiceTerritoryId = :southForkWestTerritoryId
        LIMIT 10
    ];
    System.assert(!brianWestMembers.isEmpty(), 'Brian must have a ServiceTerritoryMember for South Fork - West.');
    Datetime stmBackdate = Datetime.newInstance(2026, 1, 1, 12, 0, 0);
    for (ServiceTerritoryMember m : brianWestMembers) {
        m.EffectiveStartDate = stmBackdate;
    }
    Database.update(brianWestMembers, true);

    List<Date> visitDates = new List<Date>{
        Date.newInstance(2026, 3, 3),
        Date.newInstance(2026, 3, 17),
        Date.newInstance(2026, 3, 31),
        Date.newInstance(2026, 4, 14)
    };

    List<WorkOrder> wos = new List<WorkOrder>();
    for (Integer i = 0; i < 4; i++) {
        Date vd = visitDates[i];
        Datetime startDt = Datetime.newInstance(vd.year(), vd.month(), vd.day(), 9, 0, 0);
        Datetime endDt = Datetime.newInstance(vd.year(), vd.month(), vd.day(), 9, 30, 0);
        wos.add(
            new WorkOrder(
                AccountId = mecoxAccountId,
                AssetId = mecoxPoolAssetId,
                ServiceContractId = mecoxFY26ContractId,
                WorkTypeId = placeholderWorkTypeId,
                Subject = subjects[i],
                Status = 'New',
                StartDate = startDt,
                EndDate = endDt,
                ServiceTerritoryId = southForkWestTerritoryId
            )
        );
    }
    Database.insert(wos, true);

    Map<Id, WorkOrder> woById = new Map<Id, WorkOrder>(wos);

    List<ServiceAppointment> sasToInsert = new List<ServiceAppointment>();
    for (Integer i = 0; i < 4; i++) {
        WorkOrder wo = wos[i];
        Date vd = visitDates[i];
        Datetime startDt = Datetime.newInstance(vd.year(), vd.month(), vd.day(), 9, 0, 0);
        Datetime endDt = Datetime.newInstance(vd.year(), vd.month(), vd.day(), 9, 30, 0);
        Datetime dueDt = Datetime.newInstance(vd.year(), vd.month(), vd.day(), 23, 59, 0);
        sasToInsert.add(
            new ServiceAppointment(
                ParentRecordId = wo.Id,
                WorkTypeId = winterMaintenanceWorkTypeId,
                EarliestStartTime = startDt,
                DueDate = dueDt,
                ServiceTerritoryId = southForkWestTerritoryId,
                Duration = 30,
                DurationType = 'Minutes',
                Status = 'None'
            )
        );
    }
    Database.insert(sasToInsert, true);

    for (ServiceAppointment sa : sasToInsert) {
        WorkOrder wo = woById.get(sa.ParentRecordId);
        sa.EarliestStartTime = wo.StartDate;
        sa.DueDate = Datetime.newInstance(wo.StartDate.date().year(), wo.StartDate.date().month(), wo.StartDate.date().day(), 23, 59, 0);
        sa.SchedStartTime = wo.StartDate;
        sa.SchedEndTime = wo.EndDate;
        sa.ActualStartTime = wo.StartDate;
        sa.ActualEndTime = wo.EndDate;
        sa.Status = 'Completed';
        if (sa.ServiceTerritoryId == null) {
            sa.ServiceTerritoryId = southForkWestTerritoryId;
        }
    }
    Database.update(sasToInsert, true);

    List<AssignedResource> ars = new List<AssignedResource>();
    for (ServiceAppointment sa : sasToInsert) {
        ars.add(
            new AssignedResource(
                ServiceAppointmentId = sa.Id,
                ServiceResourceId = brianResourceId,
                IsPrimaryResource = true,
                IsRequiredResource = true
            )
        );
    }
    Database.insert(ars, true);

    List<WorkOrder> linkPlanAndWinter = new List<WorkOrder>();
    for (Integer i = 0; i < wos.size(); i++) {
        Date vd = visitDates[i];
        linkPlanAndWinter.add(
            new WorkOrder(
                Id = wos[i].Id,
                MaintenancePlanId = poolWinterPlanId,
                SuggestedMaintenanceDate = vd,
                WorkTypeId = winterMaintenanceWorkTypeId
            )
        );
    }
    Database.update(linkPlanAndWinter, true);

    List<WorkOrder> sealClosed = new List<WorkOrder>();
    for (WorkOrder wo : wos) {
        sealClosed.add(new WorkOrder(Id = wo.Id, Status = 'Closed'));
    }
    Database.update(sealClosed, true);

    List<WorkOrder> verifyWo = [
        SELECT Id, Subject, StartDate, EndDate, Status, AssetId, MaintenancePlanId, WorkTypeId
        FROM WorkOrder
        WHERE Id IN :woById.keySet()
        ORDER BY StartDate
    ];
    System.debug('VERIFY_WO ' + JSON.serialize(verifyWo));

    List<ServiceAppointment> verifySa = [
        SELECT Id, ParentRecordId, Status, ActualStartTime, ActualEndTime, ServiceTerritoryId, WorkTypeId
        FROM ServiceAppointment
        WHERE ParentRecordId IN :woById.keySet()
        ORDER BY ActualStartTime
    ];
    System.debug('VERIFY_SA ' + JSON.serialize(verifySa));

    List<AssignedResource> verifyAr = [
        SELECT ServiceAppointmentId, ServiceResource.Name
        FROM AssignedResource
        WHERE ServiceAppointmentId IN (SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woById.keySet())
    ];
    System.debug('VERIFY_AR ' + JSON.serialize(verifyAr));

    System.debug('Step 8c historical Mecox WOs + SAs + Brian ARs OK.');
} catch (Exception e) {
    Database.rollback(sp);
    System.debug(LoggingLevel.ERROR, 'Step 8c failed: ' + e.getMessage());
    throw e;
}
