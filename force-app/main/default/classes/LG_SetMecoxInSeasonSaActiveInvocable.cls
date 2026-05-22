/**
 * Flow entry: bulk-activate or bulk-deactivate pre-generated Mecox in-season Service Appointments (LG_Active__c).
 */
public with sharing class LG_SetMecoxInSeasonSaActiveInvocable {
    public class ActivateRequest {
        @InvocableVariable(
            label='Activate'
            required=true
            description='True shows pre-generated in-season appointments on the Gantt; false hides them.'
        )
        public Boolean setActive;
    }

    public class ActivateResult {
        @InvocableVariable(label='Service Appointments Updated')
        public Integer serviceAppointmentsUpdated;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Set Mecox In-Season Demo Appointments Active'
        description='Sets LG_Active__c on hand-crafted in-season Service Appointments tied to Mecox maintenance plans.'
        category='Loebs Gordon'
    )
    public static List<ActivateResult> setActive(List<ActivateRequest> requests) {
        List<ActivateResult> out = new List<ActivateResult>();
        if (requests == null || requests.isEmpty()) {
            ActivateResult r = new ActivateResult();
            r.serviceAppointmentsUpdated = 0;
            r.message = 'No requests.';
            out.add(r);
            return out;
        }
        for (ActivateRequest req : requests) {
            ActivateResult r = new ActivateResult();
            if (req == null || req.setActive == null) {
                r.serviceAppointmentsUpdated = 0;
                r.message = 'Missing activate flag.';
                out.add(r);
                continue;
            }
            Integer n = LG_MecoxInSeasonDemoService.setPreGenServiceAppointmentsActive(req.setActive);
            r.serviceAppointmentsUpdated = n;
            r.message = 'Updated ' + n + ' Service Appointment(s).';
            out.add(r);
        }
        return out;
    }
}
