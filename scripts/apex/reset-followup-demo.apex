// Removes recently created Follow-Up demo Work Orders (Subject starts with "Follow-Up:").
Datetime cutoff = Datetime.now().addMinutes(-120);
List<WorkOrder> wos = [
    SELECT Id
    FROM WorkOrder
    WHERE Subject LIKE 'Follow-Up:%' AND CreatedDate >= :cutoff
];
if (wos.isEmpty()) {
    System.debug('No follow-up Work Orders in window.');
} else {
    Set<Id> woIds = new Map<Id, WorkOrder>(wos).keySet();
    List<AssignedResource> ars = [
        SELECT Id, IsPrimaryResource, IsRequiredResource
        FROM AssignedResource
        WHERE ServiceAppointmentId IN (SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woIds)
    ];
    for (AssignedResource ar : ars) {
        ar.IsPrimaryResource = false;
        ar.IsRequiredResource = false;
    }
    update ars;
    delete [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId IN (SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woIds)];
    delete [SELECT Id FROM ServiceAppointment WHERE ParentRecordId IN :woIds];
    delete wos;
    System.debug('Removed ' + woIds.size() + ' follow-up Work Order(s) and related rows.');
}
