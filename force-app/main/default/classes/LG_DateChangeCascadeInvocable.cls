/**
 * Invocable for LG_Service_Contract_Date_Change_Cascade Flow: updates Mecox swim dates on Assets,
 * recalculates select ContractLineItem quantities, updates in-season MaintenancePlan next dates,
 * then toggles LG_Active__c on pre-generated in-season Service Appointments for the new swim date.
 */
public with sharing class LG_DateChangeCascadeInvocable {
    private static final Set<Id> MECOX_IN_SEASON_PLAN_IDS = new Set<Id>{
        Id.valueOf('1MPfj000002AQXxGAO'),
        Id.valueOf('1MPfj000002AbWbGAK'),
        Id.valueOf('1MPfj000002AbWdGAK'),
        Id.valueOf('1MPfj000002AbWeGAK')
    };

    private static final Set<Id> MECOX_ASSET_IDS = new Set<Id>{
        Id.valueOf('02ifj0000020aDdAAI'),
        Id.valueOf('02ifj0000020aDeAAI'),
        Id.valueOf('02ifj0000020aDfAAI')
    };

    public class CascadeRequest {
        @InvocableVariable(label='Service Contract ID' required=true description='Service Contract whose swim date changed.')
        public Id serviceContractId;

        @InvocableVariable(label='Old Swim Date' required=true description='Prior LG_Requested_Swim_Date__c value.')
        public Date oldSwimDate;

        @InvocableVariable(label='New Swim Date' required=true description='New LG_Requested_Swim_Date__c value.')
        public Date newSwimDate;
    }

    public class CascadeResult {
        @InvocableVariable(label='Success' description='Whether the cascade completed.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status or error message.')
        public String message;
    }

    @InvocableMethod(
        label='Execute Date Change Cascade'
        description='Updates Asset swim dates, recalculates contract line items, updates plan dates, adjusts pre-generated SA visibility'
        category='Loebs Gordon'
    )
    public static List<CascadeResult> cascade(List<CascadeRequest> requests) {
        List<CascadeResult> results = new List<CascadeResult>();
        if (requests == null || requests.isEmpty()) {
            CascadeResult r = new CascadeResult();
            r.success = false;
            r.message = 'No requests provided.';
            results.add(r);
            return results;
        }

        for (CascadeRequest req : requests) {
            CascadeResult r = new CascadeResult();
            Savepoint sp = Database.setSavepoint();
            try {
                if (req == null || req.serviceContractId == null || req.oldSwimDate == null || req.newSwimDate == null) {
                    r.success = false;
                    r.message = 'Missing required inputs.';
                    results.add(r);
                    continue;
                }

                Integer dayDelta = req.oldSwimDate.daysBetween(req.newSwimDate);
                Integer weekDelta = (Integer) Math.round(dayDelta / 7.0);

                List<Asset> assetsToUpdate = [
                    SELECT Id, LG_Swim_Date__c
                    FROM Asset
                    WHERE Id IN :MECOX_ASSET_IDS
                ];
                for (Asset a : assetsToUpdate) {
                    a.LG_Swim_Date__c = req.newSwimDate;
                }
                if (!assetsToUpdate.isEmpty()) {
                    update assetsToUpdate;
                }

                List<ContractLineItem> lineItems = [
                    SELECT Id, Quantity, Product2.ProductCode
                    FROM ContractLineItem
                    WHERE ServiceContractId = :req.serviceContractId
                ];
                for (ContractLineItem cli : lineItems) {
                    if (cli.Product2 == null || String.isBlank(cli.Product2.ProductCode)) {
                        continue;
                    }
                    if (cli.Product2.ProductCode == 'LG_WEEKLY_MAINT') {
                        cli.Quantity = Math.max(0, cli.Quantity - weekDelta);
                    } else if (cli.Product2.ProductCode == 'LG_WINTER_MAINT') {
                        cli.Quantity = Math.max(0, cli.Quantity + (weekDelta * 2));
                    }
                }
                if (!lineItems.isEmpty()) {
                    update lineItems;
                }

                List<MaintenancePlan> plansToUpdate = [
                    SELECT Id, NextSuggestedMaintenanceDate
                    FROM MaintenancePlan
                    WHERE Id IN :MECOX_IN_SEASON_PLAN_IDS
                ];

                Map<Id, Date> planToFirstFireDate = new Map<Id, Date>{
                    Id.valueOf('1MPfj000002AQXxGAO') => req.newSwimDate,
                    Id.valueOf('1MPfj000002AbWbGAK') => req.newSwimDate.addDays(-2),
                    Id.valueOf('1MPfj000002AbWdGAK') => req.newSwimDate,
                    Id.valueOf('1MPfj000002AbWeGAK') => req.newSwimDate.addDays(1)
                };

                for (MaintenancePlan p : plansToUpdate) {
                    if (planToFirstFireDate.containsKey(p.Id)) {
                        p.NextSuggestedMaintenanceDate = planToFirstFireDate.get(p.Id);
                    }
                }
                if (!plansToUpdate.isEmpty()) {
                    update plansToUpdate;
                }

                Integer visibilityUpdates = LG_MecoxInSeasonDemoService.applyPreGenSwimDateVisibility(req.newSwimDate);

                r.success = true;
                r.message =
                    'Cascade complete. Week delta: ' +
                    weekDelta +
                    '. Pre-gen SA visibility updates: ' +
                    visibilityUpdates +
                    '.';
            } catch (Exception e) {
                Database.rollback(sp);
                r.success = false;
                r.message = 'Cascade failed: ' + e.getMessage();
            }
            results.add(r);
        }

        return results;
    }

}
