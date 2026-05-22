// Loebs Gordon pool demo — Work Types + Skill Requirements (data API).
// Use when Metadata API does not expose WorkType in this org.

List<String> names = new List<String>{
    'Initial Vacuum',
    'Weekly Maintenance',
    'Chem Check',
    'Winter Service',
    'Winter Maintenance',
    'Repair / Follow-Up'
};
List<WorkType> existing = [
    SELECT Id, Name
    FROM WorkType
    WHERE Name IN :names
];
System.assert(existing.isEmpty(), 'Work Types already exist: ' + existing);

List<WorkType> wts = new List<WorkType>{
    new WorkType(
        Name = 'Initial Vacuum',
        EstimatedDuration = 4,
        DurationType = 'Hours',
        Description = 'Season-opening initial vacuum and cleanup. Lands on customer Swim Date.',
        ShouldAutoCreateSvcAppt = true
    ),
    new WorkType(
        Name = 'Weekly Maintenance',
        EstimatedDuration = 1,
        DurationType = 'Hours',
        Description = 'In-season weekly pool maintenance. Recurring via Maintenance Plan.',
        ShouldAutoCreateSvcAppt = true
    ),
    new WorkType(
        Name = 'Chem Check',
        EstimatedDuration = 30,
        DurationType = 'Minutes',
        Description = 'In-season chemical testing and balancing. Paired with Weekly Maintenance.',
        ShouldAutoCreateSvcAppt = true
    ),
    new WorkType(
        Name = 'Winter Service',
        EstimatedDuration = 3,
        DurationType = 'Hours',
        Description = 'Season-closing pool winterization.',
        ShouldAutoCreateSvcAppt = true
    ),
    new WorkType(
        Name = 'Winter Maintenance',
        EstimatedDuration = 30,
        DurationType = 'Minutes',
        Description = 'Off-season twice-monthly maintenance check.',
        ShouldAutoCreateSvcAppt = true
    ),
    new WorkType(
        Name = 'Repair / Follow-Up',
        EstimatedDuration = 1,
        DurationType = 'Hours',
        Description = 'One-off issue resolution. Created via field-tech Follow-Up flow.',
        ShouldAutoCreateSvcAppt = true
    )
};
insert wts;

Map<String, Id> skillByDev = new Map<String, Id>();
for (Skill s : [SELECT Id, DeveloperName FROM Skill WHERE DeveloperName LIKE 'LG_%']) {
    skillByDev.put(s.DeveloperName, s.Id);
}

Map<String, Id> wtIdByName = new Map<String, Id>();
for (WorkType w : wts) {
    wtIdByName.put(w.Name, w.Id);
}

List<SkillRequirement> srs = new List<SkillRequirement>{
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Initial Vacuum'),
        SkillId = skillByDev.get('LG_Initial_Vac_Specialist'),
        SkillLevel = 1
    ),
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Weekly Maintenance'),
        SkillId = skillByDev.get('LG_Pool_Tech'),
        SkillLevel = 1
    ),
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Chem Check'),
        SkillId = skillByDev.get('LG_Chem_Specialist'),
        SkillLevel = 1
    ),
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Winter Service'),
        SkillId = skillByDev.get('LG_Winterize_Certified'),
        SkillLevel = 1
    ),
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Winter Maintenance'),
        SkillId = skillByDev.get('LG_Pool_Tech'),
        SkillLevel = 1
    ),
    new SkillRequirement(
        RelatedRecordId = wtIdByName.get('Repair / Follow-Up'),
        SkillId = skillByDev.get('LG_Pool_Tech'),
        SkillLevel = 1
    )
};
insert srs;

System.debug('Inserted ' + wts.size() + ' WorkTypes and ' + srs.size() + ' SkillRequirements');
