// Rollback Step 8c hand-crafted historical Mecox WOs (four subjects Mar–Apr 2026).
// Run: sf apex run -f scripts/apex/rollback-mecox-historical-work-orders.apex --target-org sfs-demo-org

List<String> subjects = new List<String>{
    'Maintenance Mecox Pool: March 3, 2026',
    'Maintenance Mecox Pool: March 17, 2026',
    'Maintenance Mecox Pool: March 31, 2026',
    'Maintenance Mecox Pool: April 14, 2026'
};

List<Id> woIds = new List<Id>();
for (WorkOrder wo : [SELECT Id FROM WorkOrder WHERE Subject IN :subjects]) {
    woIds.add(wo.Id);
}
if (!woIds.isEmpty()) {
    List<Id> saIds = new List<Id>();
    for (ServiceAppointment sa : [SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woIds]) {
        saIds.add(sa.Id);
    }

    delete [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId IN :saIds];
    delete [SELECT Id FROM ServiceAppointment WHERE Id IN :saIds];
    delete [SELECT Id FROM WorkOrder WHERE Id IN :woIds];

    System.debug('Rollback complete. Removed WOs: ' + woIds.size());
} else {
    System.debug('No matching historical Work Orders to delete.');
}
