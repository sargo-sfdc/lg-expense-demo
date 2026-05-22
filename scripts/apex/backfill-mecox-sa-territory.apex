// One-time backfill: set ServiceTerritoryId on Mecox Work Order Service Appointments (Step 8d).
Id accountId = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1].Id;
Id swtId = [SELECT Id FROM ServiceTerritory WHERE Name = 'South Fork - West' LIMIT 1].Id;

Set<Id> woIds = new Map<Id, WorkOrder>([SELECT Id FROM WorkOrder WHERE AccountId = :accountId]).keySet();
if (woIds.isEmpty()) {
    return;
}
List<ServiceAppointment> sas = [
    SELECT Id, ServiceTerritoryId
    FROM ServiceAppointment
    WHERE ParentRecordId IN :woIds AND ServiceTerritoryId = null
];
for (ServiceAppointment sa : sas) {
    sa.ServiceTerritoryId = swtId;
}
if (!sas.isEmpty()) {
    Database.update(sas, true);
}
System.debug('Backfilled ServiceAppointment count=' + sas.size());
