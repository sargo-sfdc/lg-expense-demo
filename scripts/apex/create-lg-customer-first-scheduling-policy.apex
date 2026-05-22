// Clone OOTB "Customer First" to "LG Customer First" with tuned service goal weights.
// Policy insert auto-adds some Work Rule junction rows — skip duplicates when cloning.

Id ootbPolicyId = 'a16fj000001wdisAAA';

Integer existingLg = [SELECT COUNT() FROM FSL__Scheduling_Policy__c WHERE Name = 'LG Customer First'];
System.assertEquals(0, existingLg, 'LG Customer First policy already exists');

FSL__Scheduling_Policy__c ootb = [
    SELECT
        OwnerId,
        FSL__Description__c,
        FSL__Commit_Mode__c,
        FSL__Daily_Optimization__c,
        FSL__Fix_Overlaps__c,
        FSL__Travel_Mode__c,
        FSL__Service_Clustering_Weight__c,
        FSL__Service_Priority_Weight__c
    FROM FSL__Scheduling_Policy__c
    WHERE Id = :ootbPolicyId
];
System.assertNotEquals(null, ootb.Id);

FSL__Scheduling_Policy__c lg = new FSL__Scheduling_Policy__c(
    Name = 'LG Customer First',
    OwnerId = ootb.OwnerId,
    FSL__Description__c = 'Loebs Gordon custom policy. Cloned from OOTB Customer First with elevated preferred resource weighting.',
    FSL__Commit_Mode__c = ootb.FSL__Commit_Mode__c,
    FSL__Daily_Optimization__c = ootb.FSL__Daily_Optimization__c,
    FSL__Fix_Overlaps__c = ootb.FSL__Fix_Overlaps__c,
    FSL__Travel_Mode__c = ootb.FSL__Travel_Mode__c,
    FSL__Service_Clustering_Weight__c = ootb.FSL__Service_Clustering_Weight__c,
    FSL__Service_Priority_Weight__c = ootb.FSL__Service_Priority_Weight__c
);
insert lg;

Set<Id> workRuleIdsAlreadyOnLg = new Set<Id>();
for (FSL__Scheduling_Policy_Work_Rule__c row : [
    SELECT FSL__Work_Rule__c
    FROM FSL__Scheduling_Policy_Work_Rule__c
    WHERE FSL__Scheduling_Policy__c = :lg.Id
]) {
    workRuleIdsAlreadyOnLg.add(row.FSL__Work_Rule__c);
}

List<FSL__Scheduling_Policy_Work_Rule__c> ootbWrs = [
    SELECT FSL__Work_Rule__c
    FROM FSL__Scheduling_Policy_Work_Rule__c
    WHERE FSL__Scheduling_Policy__c = :ootbPolicyId
];
List<FSL__Scheduling_Policy_Work_Rule__c> newWrs = new List<FSL__Scheduling_Policy_Work_Rule__c>();
for (FSL__Scheduling_Policy_Work_Rule__c row : ootbWrs) {
    if (!workRuleIdsAlreadyOnLg.contains(row.FSL__Work_Rule__c)) {
        newWrs.add(
            new FSL__Scheduling_Policy_Work_Rule__c(
                FSL__Scheduling_Policy__c = lg.Id,
                FSL__Work_Rule__c = row.FSL__Work_Rule__c
            )
        );
    }
}
if (!newWrs.isEmpty()) {
    insert newWrs;
}

Integer lgWrCount = [SELECT COUNT() FROM FSL__Scheduling_Policy_Work_Rule__c WHERE FSL__Scheduling_Policy__c = :lg.Id];
Integer ootbWrCount = [SELECT COUNT() FROM FSL__Scheduling_Policy_Work_Rule__c WHERE FSL__Scheduling_Policy__c = :ootbPolicyId];
System.assertEquals(ootbWrCount, lgWrCount, 'Work rule attachment count should match OOTB after clone');

List<FSL__Scheduling_Policy_Goal__c> ootbGoals = [
    SELECT FSL__Service_Goal__c, FSL__Weight__c, FSL__Service_Goal__r.Name
    FROM FSL__Scheduling_Policy_Goal__c
    WHERE FSL__Scheduling_Policy__c = :ootbPolicyId
];
List<FSL__Scheduling_Policy_Goal__c> newGoals = new List<FSL__Scheduling_Policy_Goal__c>();
for (FSL__Scheduling_Policy_Goal__c g : ootbGoals) {
    Decimal w = g.FSL__Weight__c;
    if (g.FSL__Service_Goal__r.Name == 'Preferred Service Resource') {
        w = 30;
    } else if (g.FSL__Service_Goal__r.Name == 'Minimize Travel') {
        w = 15;
    }
    newGoals.add(
        new FSL__Scheduling_Policy_Goal__c(
            FSL__Scheduling_Policy__c = lg.Id,
            FSL__Service_Goal__c = g.FSL__Service_Goal__c,
            FSL__Weight__c = w
        )
    );
}
insert newGoals;

System.assertEquals(ootbGoals.size(), newGoals.size(), 'Goal count should match OOTB');

System.debug('LG Customer First policy Id=' + lg.Id);
