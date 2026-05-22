/**
 * Demo data generator for Expenses__c.
 *
 * Default run() targets Service Resources in the '*San Francisco' Service Territory.
 * Use overloaded methods to change territory and volume (capped at 10,000 inserts per transaction).
 *
 * Execute Anonymous: ExpenseDemoDataGenerator.run();
 * CLI: sf apex run --file scripts/apex/run-expense-demo-data.apex
 */
public class ExpenseDemoDataGenerator {
    private static final String SERVICE_TERRITORY_NAME = '*San Francisco';
    /** Defaults produce up to 5,000 rows when enough Service Resources exist */
    private static final Integer DEFAULT_MAX_RESOURCES = 100;
    private static final Integer DEFAULT_EXPENSES_PER_RESOURCE = 50;
    private static final Integer DML_BATCH = 200;
    private static final Integer MAX_ROWS_PER_RUN = 10000;

    private static final List<String> STATUS_POOL = new List<String>{
        'Draft',
        'Submitted',
        'Under Review',
        'Approved',
        'Rejected',
        'Paid'
    };

    /** Expense templates: Type, Amount (min-max range), typical days ago, Description */
    private static final List<ExpenseTemplate> TEMPLATES = new List<ExpenseTemplate>{
        new ExpenseTemplate('Fuel', 85, 125, 2, 'Work van refuel between roadside jobs on I-95'),
        new ExpenseTemplate('Fuel', 72, 98, 5, 'Full tank before morning route'),
        new ExpenseTemplate('Fuel', 110, 145, 8, 'Diesel fill-up after overnight call'),
        new ExpenseTemplate('Emergency Parts', 42, 42, 1, 'Brake chamber from NAPA for same-day repair'),
        new ExpenseTemplate('Emergency Parts', 28, 28, 3, 'Wheel seal and bearing set - local supplier'),
        new ExpenseTemplate('Emergency Parts', 67, 67, 6, 'Valve assembly and gasket, customer site fix'),
        new ExpenseTemplate('Emergency Parts', 18, 18, 4, 'Clearance lights and mounting hardware'),
        new ExpenseTemplate('Emergency Parts', 54, 54, 10, 'Specialty bolts and brake hardware'),
        new ExpenseTemplate('Local Tire Pickup', 380, 380, 0, 'TWW local tire restock - drive axle tire'),
        new ExpenseTemplate('Local Tire Pickup', 420, 420, 7, 'TWW - steer tire pickup for roadside swap'),
        new ExpenseTemplate('Local Tire Pickup', 195, 195, 12, 'TWW trailer tire, in-stock local'),
        new ExpenseTemplate('Shop Supplies', 34, 34, 1, 'Shop towels, brake cleaner, nitrile gloves'),
        new ExpenseTemplate('Shop Supplies', 22, 22, 4, 'Grease cartridges and fittings for van stock'),
        new ExpenseTemplate('Shop Supplies', 48, 48, 9, 'Safety glasses, ear plugs, hand cleaner - van restock'),
        new ExpenseTemplate('Shop Supplies', 15, 15, 11, 'Electrical tape, zip ties, wire connectors'),
        new ExpenseTemplate('Fuel', 95, 130, 14, 'Refuel after multi-stop day'),
        new ExpenseTemplate('Emergency Parts', 31, 31, 15, 'Air line fitting and seal - emergency repair')
    };

    private class ExpenseTemplate {
        String expenseType;
        Decimal amountMin;
        Decimal amountMax;
        Integer daysAgo;
        String description;
        ExpenseTemplate(String t, Integer minVal, Integer maxVal, Integer days, String descriptionText) {
            expenseType = t;
            amountMin = minVal;
            amountMax = maxVal;
            daysAgo = days;
            description = descriptionText;
        }
    }

    /**
     * Default demo run: *San Francisco territory, up to 100 Service Resources × 50 expenses (5,000 rows max).
     */
    public static Integer run() {
        return run(SERVICE_TERRITORY_NAME, DEFAULT_MAX_RESOURCES, DEFAULT_EXPENSES_PER_RESOURCE);
    }

    /**
     * Generate expenses for Service Resources in a named Service Territory (via ServiceTerritoryMember).
     * @param serviceTerritoryName Exact ServiceTerritory.Name (e.g. '*San Francisco')
     * @param maxResources Cap on number of Service Resources
     * @param expensesPerResource Rows per resource (adjusted down if total would exceed 10,000)
     * @return Number of Expenses__c rows inserted
     */
    public static Integer run(String serviceTerritoryName, Integer maxResources, Integer expensesPerResource) {
        if (String.isBlank(serviceTerritoryName)) {
            throw new DemoDataException('serviceTerritoryName is required.');
        }
        maxResources = normalizePositive(maxResources, 1);
        expensesPerResource = normalizePositive(expensesPerResource, 1);

        List<ServiceTerritoryMember> members = [
            SELECT ServiceResourceId
            FROM ServiceTerritoryMember
            WHERE ServiceTerritory.Name = :serviceTerritoryName
            WITH SECURITY_ENFORCED
        ];
        if (members.isEmpty()) {
            throw new DemoDataException(
                'No Service Territory Members found for territory named "' +
                serviceTerritoryName +
                '". Check that the Service Territory exists and has members.'
            );
        }
        Set<Id> resourceIds = new Set<Id>();
        for (ServiceTerritoryMember m : members) {
            resourceIds.add(m.ServiceResourceId);
        }
        List<ServiceResource> resources = [
            SELECT Id
            FROM ServiceResource
            WHERE Id IN :resourceIds AND RelatedRecordId != null
            WITH SECURITY_ENFORCED
            LIMIT :maxResources
        ];
        if (resources.isEmpty()) {
            throw new DemoDataException(
                'No Service Resources with a linked User found in territory "' + serviceTerritoryName + '".'
            );
        }
        return insertExpensesForResources(resources, expensesPerResource);
    }

    /**
     * Generate expenses without filtering by territory: any Service Resource with RelatedRecordId set.
     * Use when the demo org does not use the *San Francisco territory name.
     */
    public static Integer runForAnyServiceResources(Integer maxResources, Integer expensesPerResource) {
        maxResources = normalizePositive(maxResources, 1);
        expensesPerResource = normalizePositive(expensesPerResource, 1);

        List<ServiceResource> resources = [
            SELECT Id
            FROM ServiceResource
            WHERE RelatedRecordId != null
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
            LIMIT :maxResources
        ];
        if (resources.isEmpty()) {
            throw new DemoDataException('No Service Resources with RelatedRecordId set were found.');
        }
        return insertExpensesForResources(resources, expensesPerResource);
    }

    private static Integer insertExpensesForResources(List<ServiceResource> resources, Integer expensesPerResource) {
        Integer resourceCount = resources.size();
        Integer perResource = capPerResource(resourceCount, expensesPerResource);

        List<Expenses__c> buffer = new List<Expenses__c>();
        Integer inserted = 0;
        Integer templateCount = TEMPLATES.size();
        Integer seq = 0;

        for (Integer r = 0; r < resourceCount; r++) {
            Id resourceId = resources[r].Id;
            for (Integer e = 0; e < perResource; e++) {
                ExpenseTemplate t = TEMPLATES[Math.mod(seq, templateCount)];
                seq++;

                Decimal amount = t.amountMin;
                if (t.amountMax > t.amountMin) {
                    Integer range = (t.amountMax - t.amountMin).intValue();
                    amount = t.amountMin + Integer.valueOf(Math.mod(Integer.valueOf(Math.random() * 100000), range + 1));
                }
                amount = amount.setScale(2);
                Integer dayJitter = Math.mod(Integer.valueOf(Math.random() * 10000), 120);
                Date expenseDate = Date.today().addDays(-Math.min(t.daysAgo + dayJitter, 365));

                String lineNote = t.description + ' [demo #' + String.valueOf(seq) + ']';

                Expenses__c exp = new Expenses__c(
                    Service_Resource__c = resourceId,
                    Expense_Category__c = t.expenseType,
                    Expense_Amount__c = amount,
                    Expense_Date__c = expenseDate,
                    Expense_Description__c = lineNote,
                    Expense_Status__c = randomStatus()
                );
                buffer.add(exp);
                if (buffer.size() >= DML_BATCH) {
                    insert buffer;
                    inserted += buffer.size();
                    buffer.clear();
                }
            }
        }
        if (!buffer.isEmpty()) {
            insert buffer;
            inserted += buffer.size();
        }

        System.debug(
            'ExpenseDemoDataGenerator: inserted ' +
            inserted +
            ' Expenses__c across ' +
            resourceCount +
            ' Service Resources (' +
            perResource +
            ' per resource).'
        );
        return inserted;
    }

    private static Integer normalizePositive(Integer value, Integer minimum) {
        if (value == null || value < minimum) {
            return minimum;
        }
        return value;
    }

    /**
     * Ensures resourceCount * perResource <= MAX_ROWS_PER_RUN (Salesforce DML row limit per transaction).
     */
    private static Integer capPerResource(Integer resourceCount, Integer requestedPerResource) {
        if (resourceCount == 0) {
            return 0;
        }
        Long product = (Long) resourceCount * (Long) requestedPerResource;
        if (product <= MAX_ROWS_PER_RUN) {
            return requestedPerResource;
        }
        Integer capped = MAX_ROWS_PER_RUN / resourceCount;
        if (capped < 1) {
            capped = 1;
        }
        System.debug(
            'ExpenseDemoDataGenerator: capping expenses per resource from ' +
            requestedPerResource +
            ' to ' +
            capped +
            ' to stay within ' +
            MAX_ROWS_PER_RUN +
            ' rows.'
        );
        return capped;
    }

    private static String randomStatus() {
        Integer idx = Math.mod(Integer.valueOf(Math.random() * 100000), STATUS_POOL.size());
        return STATUS_POOL[idx];
    }

    public class DemoDataException extends Exception {
    }
}
