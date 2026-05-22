// Loebs Gordon pool demo — Service Resources, skills, territory memberships.
// Territories in org: "South Fork - West", "South Fork - East" (not LG-prefixed names).
//
// If Step 8e-rewire already ran, use `rewire-lg-demo-service-resources.apex` instead — do not re-run this insert script.

try {
    List<ServiceResource> existing = [
        SELECT Id, Name
        FROM ServiceResource
        WHERE Name IN ('Brian', 'Mike', 'Carlos')
    ];
    System.assert(existing.isEmpty(), 'Service Resources already exist: ' + existing);

    Map<String, Id> skillByDev = new Map<String, Id>();
    for (Skill s : [SELECT Id, DeveloperName FROM Skill WHERE DeveloperName LIKE 'LG_%']) {
        skillByDev.put(s.DeveloperName, s.Id);
    }
    System.assertEquals(6, skillByDev.size(), 'Expected six LG_ skills');

    List<ServiceTerritory> territories = [
        SELECT Id, Name, OperatingHoursId
        FROM ServiceTerritory
        WHERE Name IN ('South Fork - West', 'South Fork - East')
    ];
    System.assertEquals(2, territories.size(), 'Expected South Fork West and East territories');

    Map<String, ServiceTerritory> territoryByName = new Map<String, ServiceTerritory>();
    for (ServiceTerritory st : territories) {
        territoryByName.put(st.Name, st);
    }

    // Three active Standard users with no existing ServiceResource (verified via SOQL before script).
    Id userBrian = '005fj00000E4fJ6AAJ'; // Bill South
    Id userMike = '005fj00000E4fJ3AAJ'; // Ely East
    Id userCarlos = '005fj00000E4fKBAAZ'; // Brenda Service

    Datetime effectiveStart = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

    List<ServiceResource> srsToInsert = new List<ServiceResource>{
        new ServiceResource(
            Name = 'Brian',
            RelatedRecordId = userBrian,
            ResourceType = 'T',
            IsActive = true
        ),
        new ServiceResource(
            Name = 'Mike',
            RelatedRecordId = userMike,
            ResourceType = 'T',
            IsActive = true
        ),
        new ServiceResource(
            Name = 'Carlos',
            RelatedRecordId = userCarlos,
            ResourceType = 'T',
            IsActive = true
        )
    };
    insert srsToInsert;

    Map<String, Id> srIdByName = new Map<String, Id>();
    for (ServiceResource sr : srsToInsert) {
        srIdByName.put(sr.Name, sr.Id);
    }

    List<ServiceResourceSkill> skillsToInsert = new List<ServiceResourceSkill>{
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Brian'),
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Brian'),
            SkillId = skillByDev.get('LG_Initial_Vac_Specialist'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Brian'),
            SkillId = skillByDev.get('LG_Chem_Specialist'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Mike'),
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Mike'),
            SkillId = skillByDev.get('LG_Spa_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Mike'),
            SkillId = skillByDev.get('LG_Heater_Repair'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Carlos'),
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srIdByName.get('Carlos'),
            SkillId = skillByDev.get('LG_Winterize_Certified'),
            EffectiveStartDate = effectiveStart
        )
    };
    insert skillsToInsert;

    Id westId = territoryByName.get('South Fork - West').Id;
    Id eastId = territoryByName.get('South Fork - East').Id;
    Id territoryOh = territoryByName.get('South Fork - West').OperatingHoursId;
    System.assert(territoryOh != null, 'Territory OperatingHoursId required');
    System.assertEquals(
        territoryOh,
        territoryByName.get('South Fork - East').OperatingHoursId,
        'West and East share same OperatingHours in this org'
    );

    List<ServiceTerritoryMember> membersToInsert = new List<ServiceTerritoryMember>{
        new ServiceTerritoryMember(
            ServiceResourceId = srIdByName.get('Brian'),
            ServiceTerritoryId = westId,
            TerritoryType = 'P',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srIdByName.get('Mike'),
            ServiceTerritoryId = eastId,
            TerritoryType = 'P',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srIdByName.get('Carlos'),
            ServiceTerritoryId = westId,
            TerritoryType = 'S',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srIdByName.get('Carlos'),
            ServiceTerritoryId = eastId,
            TerritoryType = 'S',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        )
    };
    insert membersToInsert;

    System.assertEquals(3, srsToInsert.size(), 'SR count');
    System.assertEquals(8, skillsToInsert.size(), 'SRS count');
    System.assertEquals(4, membersToInsert.size(), 'STM count');

    System.debug('OK Brian=' + srIdByName.get('Brian'));
    System.debug('OK Mike=' + srIdByName.get('Mike'));
    System.debug('OK Carlos=' + srIdByName.get('Carlos'));
} catch (DmlException e) {
    for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug(
            LoggingLevel.ERROR,
            'DML ' +
                i +
                ' status=' +
                e.getDmlStatusCode(i) +
                ' fields=' +
                e.getDmlFieldNames(i) +
                ' msg=' +
                e.getDmlMessage(i)
        );
    }
    throw e;
}
