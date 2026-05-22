// Smoke: invoke LG_GenerateWorkOrdersInvocable for Pool Off-Season Winter Maintenance plan (creates WOs).
LG_GenerateWorkOrdersInvocable.GenerateRequest req = new LG_GenerateWorkOrdersInvocable.GenerateRequest();
req.maintenancePlanIds = new List<Id>{ '1MPfj000002AbWcGAK' };

List<LG_GenerateWorkOrdersInvocable.GenerateResult> results = LG_GenerateWorkOrdersInvocable.generate(
    new List<LG_GenerateWorkOrdersInvocable.GenerateRequest>{ req }
);
for (LG_GenerateWorkOrdersInvocable.GenerateResult r : results) {
    System.debug('SMOKE_RESULT success=' + r.success + ' msg=' + r.message);
}
