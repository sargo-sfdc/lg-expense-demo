// Mecox Estate seed: Products, PricebookEntries, Account, Assets, ServiceContract, ContractLineItems.
// Account.Type: org picklist has no "Customer — Direct"; Type left null (see runbook).
// ServiceContract.Status is not createable in this org; verify Status after insert.

System.assert(
    [SELECT COUNT() FROM Account WHERE Name = 'Mecox Estate'] == 0,
    'Mecox Estate already exists'
);

Pricebook2 stdPb = [
    SELECT Id, CurrencyIsoCode, IsActive
    FROM Pricebook2
    WHERE IsStandard = true
    LIMIT 1
];
System.assertEquals(true, stdPb.IsActive, 'Standard price book must be active');
Id stdPbId = stdPb.Id;
String pbCurrency = String.isBlank(stdPb.CurrencyIsoCode) ? 'USD' : stdPb.CurrencyIsoCode;

Savepoint sp = Database.setSavepoint();
try {
    Set<String> productCodes = new Set<String>{
        'LG_WEEKLY_MAINT',
        'LG_INITIAL_VAC',
        'LG_WINTER_SERVICE',
        'LG_WINTER_MAINT',
        'LG_FOUNTAIN_ADDON',
        'LG_FOUNTAIN_ONLY'
    };

    Map<String, Id> productIdByCode = new Map<String, Id>();
    for (Product2 existing : [
        SELECT Id, ProductCode
        FROM Product2
        WHERE ProductCode IN :productCodes
    ]) {
        productIdByCode.put(existing.ProductCode, existing.Id);
    }

    List<Product2> productsToInsert = new List<Product2>();
    if (!productIdByCode.containsKey('LG_WEEKLY_MAINT')) {
        productsToInsert.add(
            new Product2(
                Name = 'Weekly Maintenance',
                ProductCode = 'LG_WEEKLY_MAINT',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productIdByCode.containsKey('LG_INITIAL_VAC')) {
        productsToInsert.add(
            new Product2(
                Name = 'Initial Vacuum',
                ProductCode = 'LG_INITIAL_VAC',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productIdByCode.containsKey('LG_WINTER_SERVICE')) {
        productsToInsert.add(
            new Product2(
                Name = 'Winter Service',
                ProductCode = 'LG_WINTER_SERVICE',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productIdByCode.containsKey('LG_WINTER_MAINT')) {
        productsToInsert.add(
            new Product2(
                Name = 'Winter Maintenance',
                ProductCode = 'LG_WINTER_MAINT',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productIdByCode.containsKey('LG_FOUNTAIN_ADDON')) {
        productsToInsert.add(
            new Product2(
                Name = 'Fountain Add-On',
                ProductCode = 'LG_FOUNTAIN_ADDON',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productIdByCode.containsKey('LG_FOUNTAIN_ONLY')) {
        productsToInsert.add(
            new Product2(
                Name = 'Fountain-Only Service',
                ProductCode = 'LG_FOUNTAIN_ONLY',
                Family = 'Service',
                IsActive = true
            )
        );
    }
    if (!productsToInsert.isEmpty()) {
        Database.insert(productsToInsert, true);
        for (Product2 p : productsToInsert) {
            productIdByCode.put(p.ProductCode, p.Id);
        }
    }
    System.assertEquals(6, productIdByCode.size());

    Map<String, Decimal> unitPriceByCode = new Map<String, Decimal>{
        'LG_WEEKLY_MAINT' => 425,
        'LG_INITIAL_VAC' => 1500,
        'LG_WINTER_SERVICE' => 850,
        'LG_WINTER_MAINT' => 125,
        'LG_FOUNTAIN_ADDON' => 60,
        'LG_FOUNTAIN_ONLY' => 225
    };

    Map<String, Id> pbeIdByProductCode = new Map<String, Id>();
    for (PricebookEntry pbe : [
        SELECT Id, Product2.ProductCode
        FROM PricebookEntry
        WHERE Pricebook2Id = :stdPbId AND Product2.ProductCode IN :productCodes
    ]) {
        pbeIdByProductCode.put(pbe.Product2.ProductCode, pbe.Id);
    }

    List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
    for (String code : productCodes) {
        if (!pbeIdByProductCode.containsKey(code)) {
            pbesToInsert.add(
                new PricebookEntry(
                    Pricebook2Id = stdPbId,
                    Product2Id = productIdByCode.get(code),
                    UnitPrice = unitPriceByCode.get(code),
                    IsActive = true,
                    UseStandardPrice = false,
                    CurrencyIsoCode = pbCurrency
                )
            );
        }
    }
    if (!pbesToInsert.isEmpty()) {
        Database.insert(pbesToInsert, true);
    }

    pbeIdByProductCode.clear();
    for (PricebookEntry pbe : [
        SELECT Id, Product2.ProductCode
        FROM PricebookEntry
        WHERE Pricebook2Id = :stdPbId AND Product2.ProductCode IN :productCodes
    ]) {
        pbeIdByProductCode.put(pbe.Product2.ProductCode, pbe.Id);
    }
    System.assertEquals(6, pbeIdByProductCode.size());

    Account mecox = new Account(
        Name = 'Mecox Estate',
        BillingStreet = 'Mecox Road',
        BillingCity = 'Bridgehampton',
        BillingState = 'NY',
        BillingPostalCode = '11932',
        BillingCountry = 'US',
        ShippingStreet = 'Mecox Road',
        ShippingCity = 'Bridgehampton',
        ShippingState = 'NY',
        ShippingPostalCode = '11932',
        ShippingCountry = 'US'
    );
    Database.insert(new List<Account>{ mecox }, true);
    Id accountId = mecox.Id;

    Date swim = Date.newInstance(2026, 5, 6);
    Date poolWinterTarget = Date.newInstance(2026, 10, 24);
    Date fountainWinterTarget = Date.newInstance(2026, 12, 15);
    Date installPool = Date.newInstance(2018, 6, 1);
    Date installFountain = Date.newInstance(2020, 4, 15);

    Asset pool = new Asset(
        Name = 'Mecox Pool',
        AccountId = accountId,
        ParentId = null,
        Status = 'Installed',
        InstallDate = installPool,
        LG_Lifecycle_Status__c = 'Winterized',
        LG_Swim_Date__c = swim,
        LG_Winterize_Date_Target__c = poolWinterTarget
    );
    Database.insert(new List<Asset>{ pool }, true);
    Id poolId = pool.Id;

    Asset spa = new Asset(
        Name = 'Mecox Spa',
        AccountId = accountId,
        ParentId = poolId,
        Status = 'Installed',
        InstallDate = installPool,
        LG_Lifecycle_Status__c = 'Winterized',
        LG_Swim_Date__c = swim,
        LG_Winterize_Date_Target__c = poolWinterTarget
    );
    Asset fountain = new Asset(
        Name = 'Mecox Fountain',
        AccountId = accountId,
        ParentId = null,
        Status = 'Installed',
        InstallDate = installFountain,
        LG_Lifecycle_Status__c = 'Winterized',
        LG_Swim_Date__c = swim,
        LG_Winterize_Date_Target__c = fountainWinterTarget
    );
    Database.insert(new List<Asset>{ spa, fountain }, true);

    ServiceContract sc = new ServiceContract(
        Name = 'Mecox Estate FY26 Annual',
        AccountId = accountId,
        StartDate = Date.newInstance(2026, 4, 1),
        EndDate = Date.newInstance(2027, 3, 31),
        Pricebook2Id = stdPbId,
        Description = 'FY26 annual contract. 24 wks pool maintenance, 28 wks winter coverage, fountain extended through Dec 15.',
        LG_Requested_Swim_Date__c = swim
    );
    Database.insert(new List<ServiceContract>{ sc }, true);
    Id scId = sc.Id;

    List<ContractLineItem> clis = new List<ContractLineItem>{
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_WEEKLY_MAINT'),
            Quantity = 24,
            UnitPrice = 425,
            Description = 'Pool weekly service, May–Oct'
        ),
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_INITIAL_VAC'),
            Quantity = 1,
            UnitPrice = 1500,
            Description = 'Season-opening vacuum'
        ),
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_WINTER_SERVICE'),
            Quantity = 1,
            UnitPrice = 850,
            Description = 'Pool winterization'
        ),
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_WINTER_MAINT'),
            Quantity = 26,
            UnitPrice = 125,
            Description = 'Off-season twice-monthly checks'
        ),
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_FOUNTAIN_ADDON'),
            Quantity = 32,
            UnitPrice = 60,
            Description = 'Fountain extension when pool open'
        ),
        new ContractLineItem(
            ServiceContractId = scId,
            PricebookEntryId = pbeIdByProductCode.get('LG_FOUNTAIN_ONLY'),
            Quantity = 12,
            UnitPrice = 225,
            Description = 'Fountain service Dec 15–Apr'
        )
    };
    Database.insert(clis, true);

    System.debug('Mecox AccountId=' + accountId);
    System.debug('Mecox Pool AssetId=' + poolId);
    System.debug('Mecox ServiceContractId=' + scId);
    System.debug('ServiceContract Status (read-only on insert)=' + [SELECT Status FROM ServiceContract WHERE Id = :scId].Status);
} catch (DmlException e) {
    Database.rollback(sp);
    for (Integer i = 0; i < e.getNumDml(); i++) {
        System.debug(
            LoggingLevel.ERROR,
            'DML row ' +
                i +
                ' ' +
                e.getDmlMessage(i) +
                ' fields=' +
                e.getDmlFieldNames(i)
        );
    }
    throw e;
}
