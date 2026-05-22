/**
 * Invocable entry for Flow: toggles MaintenancePlan.DoesAutoGenerateWorkOrders off, calls the standard
 * generateWorkOrders REST action in a separate transaction (Queueable), then restores the flag.
 */
public with sharing class LG_GenerateWorkOrdersInvocable {
    private static final String GENERATE_WORK_ORDERS_PATH = '/services/data/v66.0/actions/standard/generateWorkOrders';

    public class GenerateRequest {
        @InvocableVariable(
            label='Maintenance Plan IDs'
            required=true
            description='IDs of Maintenance Plans to generate Work Orders for.'
        )
        public List<Id> maintenancePlanIds;
    }

    public class GenerateResult {
        @InvocableVariable(label='Success' description='Whether generation was successfully scheduled.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status or error message.')
        public String message;
    }

    @InvocableMethod(
        label='Generate Work Orders for Maintenance Plans'
        description='Turns auto-generate off, invokes generateWorkOrders REST action, then restores auto-generate. For LG cascade Flows.'
        category='Loebs Gordon'
    )
    public static List<GenerateResult> generate(List<GenerateRequest> requests) {
        List<GenerateResult> results = new List<GenerateResult>();

        Set<Id> allPlanIds = new Set<Id>();
        if (requests != null) {
            for (GenerateRequest req : requests) {
                if (req != null && req.maintenancePlanIds != null) {
                    allPlanIds.addAll(req.maintenancePlanIds);
                }
            }
        }

        if (allPlanIds.isEmpty()) {
            GenerateResult r = new GenerateResult();
            r.success = false;
            r.message = 'No Maintenance Plan IDs provided.';
            results.add(r);
            return results;
        }

        List<MaintenancePlan> plansToDisable = [
            SELECT Id, DoesAutoGenerateWorkOrders
            FROM MaintenancePlan
            WHERE Id IN :allPlanIds
        ];

        if (plansToDisable.isEmpty()) {
            GenerateResult r = new GenerateResult();
            r.success = false;
            r.message = 'No Maintenance Plans found for the given IDs.';
            results.add(r);
            return results;
        }

        Map<Id, Boolean> originalAutoGenStates = new Map<Id, Boolean>();
        for (MaintenancePlan p : plansToDisable) {
            originalAutoGenStates.put(p.Id, p.DoesAutoGenerateWorkOrders);
            p.DoesAutoGenerateWorkOrders = false;
        }

        try {
            update plansToDisable;
        } catch (DmlException e) {
            GenerateResult r = new GenerateResult();
            r.success = false;
            r.message = 'Failed to disable auto-generate: ' + e.getMessage();
            results.add(r);
            return results;
        }

        Set<Id> planIdsForJob = originalAutoGenStates.keySet();
        String sessionId = UserInfo.getSessionId();

        try {
            Id jobId = System.enqueueJob(
                new GenerateWorkOrdersQueueable(planIdsForJob, originalAutoGenStates, sessionId)
            );
            GenerateResult r = new GenerateResult();
            r.success = true;
            r.message = 'Generation scheduled. Job ID: ' + String.valueOf(jobId) + '. Plans: ' + planIdsForJob.size() + '.';
            results.add(r);
            return results;
        } catch (Exception e) {
            restoreDoesAutoGenerate(planIdsForJob, originalAutoGenStates);
            GenerateResult r = new GenerateResult();
            r.success = false;
            r.message = 'Failed to enqueue job: ' + e.getMessage();
            results.add(r);
            return results;
        }
    }

    private static void restoreDoesAutoGenerate(Set<Id> planIds, Map<Id, Boolean> originalStates) {
        if (planIds == null || planIds.isEmpty() || originalStates == null || originalStates.isEmpty()) {
            return;
        }
        List<MaintenancePlan> plans = [
            SELECT Id, DoesAutoGenerateWorkOrders
            FROM MaintenancePlan
            WHERE Id IN :planIds
        ];
        for (MaintenancePlan p : plans) {
            if (originalStates.containsKey(p.Id)) {
                p.DoesAutoGenerateWorkOrders = originalStates.get(p.Id);
            }
        }
        try {
            update plans;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'LG_GenerateWorkOrdersInvocable: restore failed: ' + e.getMessage());
        }
    }

    public class GenerateWorkOrdersQueueable implements Queueable, Database.AllowsCallouts {
        private final Set<Id> planIds;
        private final Map<Id, Boolean> originalStates;
        private final String sessionId;

        public GenerateWorkOrdersQueueable(Set<Id> planIds, Map<Id, Boolean> originalStates, String sessionId) {
            this.planIds = planIds == null ? new Set<Id>() : planIds.clone();
            this.originalStates = originalStates == null ? new Map<Id, Boolean>() : originalStates.clone();
            this.sessionId = sessionId;
        }

        public void execute(QueueableContext context) {
            if (!planIds.isEmpty()) {
                syncWorkRuleDatesFromPlans(planIds);

                List<Map<String, Object>> inputs = new List<Map<String, Object>>();
                for (Id planId : planIds) {
                    inputs.add(new Map<String, Object>{ 'recordId' => planId });
                }
                Map<String, Object> body = new Map<String, Object>{ 'inputs' => inputs };

                HttpRequest req = new HttpRequest();
                String base = URL.getOrgDomainUrl().toExternalForm();
                req.setEndpoint(base + GENERATE_WORK_ORDERS_PATH);
                req.setMethod('POST');
                String bearer = String.isBlank(sessionId) ? UserInfo.getSessionId() : sessionId;
                req.setHeader('Authorization', 'Bearer ' + bearer);
                req.setHeader('Content-Type', 'application/json');
                req.setBody(JSON.serialize(body));

                try {
                    HttpResponse res = new Http().send(req);
                    if (res.getStatusCode() == 200) {
                        System.debug(
                            'LG_GenerateWorkOrdersInvocable: generateWorkOrders HTTP 200. Plans=' + planIds.size()
                        );
                    } else {
                        System.debug(
                            LoggingLevel.ERROR,
                            'LG_GenerateWorkOrdersInvocable: HTTP ' +
                                res.getStatusCode() +
                                ' Body=' +
                                res.getBody()
                        );
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'LG_GenerateWorkOrdersInvocable: callout error: ' + e.getMessage());
                }
            }

            restoreInQueueable(planIds, originalStates);
        }

        /**
         * generateWorkOrders uses MaintenanceWorkRule dates; copy each plan's NextSuggestedMaintenanceDate
         * onto its rules before the REST callout. Plans must keep DoesAutoGenerateWorkOrders = false during the
         * standard action (see Actions API: generateWorkOrders).
         */
        private void syncWorkRuleDatesFromPlans(Set<Id> planIdSet) {
            if (planIdSet == null || planIdSet.isEmpty()) {
                return;
            }
            try {
                List<MaintenancePlan> plansWithDates = [
                    SELECT Id, NextSuggestedMaintenanceDate
                    FROM MaintenancePlan
                    WHERE Id IN :planIdSet
                ];
                Map<Id, Date> planIdToDate = new Map<Id, Date>();
                for (MaintenancePlan p : plansWithDates) {
                    planIdToDate.put(p.Id, p.NextSuggestedMaintenanceDate);
                }

                List<MaintenanceWorkRule> rulesToSync = [
                    SELECT Id, ParentMaintenancePlanId, NextSuggestedMaintenanceDate
                    FROM MaintenanceWorkRule
                    WHERE ParentMaintenancePlanId IN :planIdSet
                ];
                for (MaintenanceWorkRule r : rulesToSync) {
                    if (planIdToDate.containsKey(r.ParentMaintenancePlanId)) {
                        r.NextSuggestedMaintenanceDate = planIdToDate.get(r.ParentMaintenancePlanId);
                    }
                }
                if (!rulesToSync.isEmpty()) {
                    update rulesToSync;
                }
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'LG_GenerateWorkOrdersInvocable: syncWorkRuleDatesFromPlans failed: ' + e.getMessage()
                );
            }
        }

        private void restoreInQueueable(Set<Id> planIds, Map<Id, Boolean> originalStates) {
            if (planIds.isEmpty()) {
                return;
            }
            List<MaintenancePlan> plansToRestore = [
                SELECT Id, DoesAutoGenerateWorkOrders
                FROM MaintenancePlan
                WHERE Id IN :planIds
            ];
            for (MaintenancePlan p : plansToRestore) {
                if (originalStates.containsKey(p.Id)) {
                    p.DoesAutoGenerateWorkOrders = originalStates.get(p.Id);
                }
            }
            try {
                update plansToRestore;
            } catch (DmlException e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'LG_GenerateWorkOrdersInvocable: Failed to restore DoesAutoGenerateWorkOrders: ' + e.getMessage()
                );
            }
        }
    }
}
