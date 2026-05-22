/**
 * Invoked from auto-launched Flow LG_Create_Followup_Work_Order (Quick Action on Service Appointment).
 * Creates a next-day Repair / Follow-Up Work Order from the calling SA's parent Work Order context,
 * activates the auto-created Service Appointment for the Gantt, and assigns Brian.
 */
public with sharing class LG_CreateFollowupWorkOrderInvocable {
    private static final Id BRIAN_SERVICE_RESOURCE_ID = Id.valueOf('0Hnfj0000004KV5CAM');

    public class InvocableException extends Exception {
    }

    public class Request {
        @InvocableVariable(
            label='Record Id'
            required=true
            description='Id of the Service Appointment the technician is viewing.'
        )
        public String recordId;
    }

    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Work Order Id')
        public Id workOrderId;

        @InvocableVariable(label='Service Appointment Id')
        public Id serviceAppointmentId;
    }

    @InvocableMethod(
        label='Create Follow-Up Work Order from Service Appointment'
        description='Creates a tomorrow Repair/Follow-Up Work Order from the parent Work Order of the given Service Appointment, assigns Brian.'
        category='Loebs Gordon'
    )
    public static List<Result> createFollowUp(List<Request> requests) {
        if (requests == null || requests.isEmpty() || requests[0] == null) {
            throw new InvocableException('Missing input.');
        }
        Request req = requests[0];
        if (String.isBlank(req.recordId)) {
            throw new InvocableException('Missing Service Appointment Id.');
        }
        Id saId;
        try {
            saId = Id.valueOf(req.recordId.trim());
        } catch (Exception e) {
            throw new InvocableException('Invalid Service Appointment Id.');
        }
        return new List<Result>{ processOne(saId) };
    }

    private static Result processOne(Id serviceAppointmentId) {
        Savepoint sp = Database.setSavepoint();
        try {
            List<ServiceAppointment> saRows = [
                SELECT Id, ParentRecordId
                FROM ServiceAppointment
                WHERE Id = :serviceAppointmentId
                LIMIT 1
            ];
            if (saRows.isEmpty()) {
                throw new InvocableException('Service Appointment not found.');
            }
            Id woId = saRows[0].ParentRecordId;
            if (woId == null) {
                throw new InvocableException('Service Appointment has no parent Work Order.');
            }

            List<WorkOrder> woRows = [
                SELECT Id, AccountId, AssetId, ServiceContractId
                FROM WorkOrder
                WHERE Id = :woId
                LIMIT 1
            ];
            if (woRows.isEmpty()) {
                throw new InvocableException('Parent Work Order not found.');
            }
            WorkOrder parentWo = woRows[0];

            String assetName = 'Unknown';
            if (parentWo.AssetId != null) {
                List<Asset> assets = [
                    SELECT Name
                    FROM Asset
                    WHERE Id = :parentWo.AssetId
                    LIMIT 1
                ];
                if (!assets.isEmpty() && !String.isBlank(assets[0].Name)) {
                    assetName = assets[0].Name;
                }
            }

            List<WorkType> wts = [
                SELECT Id
                FROM WorkType
                WHERE Name = 'Repair / Follow-Up'
                LIMIT 1
            ];
            if (wts.isEmpty()) {
                throw new InvocableException('Work Type "Repair / Follow-Up" not found.');
            }

            Date tomorrow = Date.today().addDays(1);
            Datetime startDt = Datetime.newInstance(tomorrow.year(), tomorrow.month(), tomorrow.day(), 9, 0, 0);
            Datetime endDt = startDt.addHours(1);

            WorkOrder newWo = new WorkOrder(
                AccountId = parentWo.AccountId,
                AssetId = parentWo.AssetId,
                ServiceContractId = parentWo.ServiceContractId,
                WorkTypeId = wts[0].Id,
                Subject = 'Follow-Up: Issue at ' + assetName,
                Status = 'New',
                StartDate = startDt,
                EndDate = endDt,
                Description = 'Auto-created from Follow-Up Required action on Service Appointment ' + String.valueOf(serviceAppointmentId)
            );
            insert newWo;

            List<ServiceAppointment> newSas = [
                SELECT Id
                FROM ServiceAppointment
                WHERE ParentRecordId = :newWo.Id
                LIMIT 1
            ];
            if (newSas.isEmpty()) {
                Database.rollback(sp);
                throw new InvocableException('No Service Appointment was auto-created for the new Work Order.');
            }
            ServiceAppointment newSa = newSas[0];
            newSa.LG_Active__c = true;
            newSa.EarliestStartTime = newWo.StartDate;
            newSa.DueDate = newWo.EndDate;
            newSa.SchedStartTime = newWo.StartDate;
            newSa.SchedEndTime = newWo.EndDate;
            update newSa;

            AssignedResource ar = new AssignedResource(
                ServiceAppointmentId = newSa.Id,
                ServiceResourceId = BRIAN_SERVICE_RESOURCE_ID,
                IsPrimaryResource = true,
                IsRequiredResource = true
            );
            insert ar;

            Result r = new Result();
            r.success = true;
            r.message = 'Follow-up Work Order created.';
            r.workOrderId = newWo.Id;
            r.serviceAppointmentId = newSa.Id;
            return r;
        } catch (InvocableException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new InvocableException(e.getMessage(), e);
        }
    }
}
