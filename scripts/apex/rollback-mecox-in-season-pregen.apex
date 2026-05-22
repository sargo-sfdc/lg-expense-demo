// Deletes in-season-plan Work Orders that have StartDate (hand-seeded demo rows).
Set<Id> planIds = new Set<Id>{
    Id.valueOf('1MPfj000002AQXxGAO'),
    Id.valueOf('1MPfj000002AbWbGAK'),
    Id.valueOf('1MPfj000002AbWdGAK'),
    Id.valueOf('1MPfj000002AbWeGAK')
};
List<WorkOrder> wos = [
    SELECT Id
    FROM WorkOrder
    WHERE MaintenancePlanId IN :planIds AND StartDate != NULL
];
if (wos.isEmpty()) {
    System.debug('No matching Work Orders to delete.');
} else {
    Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();
    delete [SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woIds];
    delete wos;
    System.debug('Deleted ' + woIds.size() + ' Work Orders and related Service Appointments.');
}
