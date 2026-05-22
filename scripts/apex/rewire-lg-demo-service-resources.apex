// Step 8e-rewire: Retire Step 5 Brian/Mike/Carlos (non-FSL users), repurpose Andy James / James Clifton /
// Gloria Barnes (FSL-licensed) as Brian / Mike / Carlos with South Fork STMs and LG_ skills.
// Note: Some orgs disallow DELETE on ServiceResource via Apex; this script deactivates + renames Step 5 rows instead.
// Run: sf apex run --file scripts/apex/rewire-lg-demo-service-resources.apex --target-org sfs-demo-org

Savepoint sp = Database.setSavepoint();
try {
    Id userBillSouth = '005fj00000E4fJ6AAJ';
    Id userElyEast = '005fj00000E4fJ3AAJ';
    Id userBrendaService = '005fj00000E4fKBAAZ';

    Id srAndy = '0Hnfj0000004KV5CAM';
    Id srJames = '0Hnfj0000004KV4CAM';
    Id srGloria = '0Hnfj0000004KUtCAM';

    List<ServiceResource> step5 = [
        SELECT Id, Name, RelatedRecordId
        FROM ServiceResource
        WHERE
            Name IN ('Brian', 'Mike', 'Carlos')
            AND RelatedRecordId IN (:userBillSouth, :userElyEast, :userBrendaService)
    ];
    System.assertEquals(3, step5.size(), 'Expected three Step 5 ServiceResources (Bill/Ely/Brenda). Found: ' + step5);

    Set<Id> step5Ids = new Set<Id>();
    for (ServiceResource sr : step5) {
        step5Ids.add(sr.Id);
    }

    if (![SELECT Id FROM AssignedResource WHERE ServiceResourceId IN :step5Ids LIMIT 1].isEmpty()) {
        System.assert(false, 'Step 5 ServiceResources have AssignedResource rows; delete blocked.');
    }

    List<ServiceResource> repurposeRows = [
        SELECT Id, Name
        FROM ServiceResource
        WHERE Id IN (:srAndy, :srJames, :srGloria)
    ];
    System.assertEquals(3, repurposeRows.size(), 'Expected Andy James, James Clifton, Gloria Barnes ServiceResources.');

    Set<Id> repurposeIds = new Set<Id>{ srAndy, srJames, srGloria };

    delete [SELECT Id FROM ServiceTerritoryMember WHERE ServiceResourceId IN :step5Ids];
    delete [SELECT Id FROM ServiceResourceSkill WHERE ServiceResourceId IN :step5Ids];

    List<ServiceResource> retireStep5 = new List<ServiceResource>();
    for (ServiceResource sr : step5) {
        String sid = String.valueOf(sr.Id);
        String tail = sid.length() > 6 ? sid.substring(sid.length() - 6) : sid;
        retireStep5.add(
            new ServiceResource(
                Id = sr.Id,
                IsActive = false,
                Name = 'LG_retired_Step5_' + sr.Name + '_' + tail
            )
        );
    }
    Database.update(retireStep5, true);

    delete [SELECT Id FROM ServiceTerritoryMember WHERE ServiceResourceId IN :repurposeIds];
    delete [SELECT Id FROM ServiceResourceSkill WHERE ServiceResourceId IN :repurposeIds];

    List<ServiceResource> renames = new List<ServiceResource>{
        new ServiceResource(Id = srAndy, Name = 'Brian'),
        new ServiceResource(Id = srJames, Name = 'Mike'),
        new ServiceResource(Id = srGloria, Name = 'Carlos')
    };
    Database.update(renames, true);

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

    Id westId = territoryByName.get('South Fork - West').Id;
    Id eastId = territoryByName.get('South Fork - East').Id;
    Id territoryOh = territoryByName.get('South Fork - West').OperatingHoursId;
    System.assert(territoryOh != null, 'Territory OperatingHoursId required');
    System.assertEquals(
        territoryOh,
        territoryByName.get('South Fork - East').OperatingHoursId,
        'West and East must share OperatingHours in this org'
    );

    Datetime effectiveStart = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

    List<ServiceTerritoryMember> membersToInsert = new List<ServiceTerritoryMember>{
        new ServiceTerritoryMember(
            ServiceResourceId = srAndy,
            ServiceTerritoryId = westId,
            TerritoryType = 'P',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srJames,
            ServiceTerritoryId = eastId,
            TerritoryType = 'P',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srGloria,
            ServiceTerritoryId = westId,
            TerritoryType = 'S',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        ),
        new ServiceTerritoryMember(
            ServiceResourceId = srGloria,
            ServiceTerritoryId = eastId,
            TerritoryType = 'S',
            EffectiveStartDate = effectiveStart,
            OperatingHoursId = territoryOh
        )
    };
    Database.insert(membersToInsert, true);

    List<ServiceResourceSkill> skillsToInsert = new List<ServiceResourceSkill>{
        new ServiceResourceSkill(
            ServiceResourceId = srAndy,
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srAndy,
            SkillId = skillByDev.get('LG_Initial_Vac_Specialist'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srAndy,
            SkillId = skillByDev.get('LG_Chem_Specialist'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srJames,
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srJames,
            SkillId = skillByDev.get('LG_Spa_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srJames,
            SkillId = skillByDev.get('LG_Heater_Repair'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srGloria,
            SkillId = skillByDev.get('LG_Pool_Tech'),
            EffectiveStartDate = effectiveStart
        ),
        new ServiceResourceSkill(
            ServiceResourceId = srGloria,
            SkillId = skillByDev.get('LG_Winterize_Certified'),
            EffectiveStartDate = effectiveStart
        )
    };
    Database.insert(skillsToInsert, true);

    System.debug(
        'Step 8e-rewire OK. Brian=' +
            srAndy +
            ' Mike=' +
            srJames +
            ' Carlos=' +
            srGloria +
            ' (same Ids as former Andy/James/Gloria).'
    );
} catch (Exception e) {
    Database.rollback(sp);
    System.debug(LoggingLevel.ERROR, 'Step 8e-rewire failed: ' + e.getMessage());
    throw e;
}
