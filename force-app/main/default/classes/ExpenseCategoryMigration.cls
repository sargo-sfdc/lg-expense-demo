/**
 * One-time migration: copy Expense_Type__c to Expense_Category__c on all Expenses__c records
 * where the type value matches the Expense Category picklist (Fuel, Emergency Parts, Local Tire Pickup, Shop Supplies).
 * Run via Execute Anonymous: ExpenseCategoryMigration.run();
 * Or from CLI: sf apex run --file scripts/apex/run-expense-category-migration.apex
 */
public with sharing class ExpenseCategoryMigration {
    private static final Set<String> VALID_CATEGORIES = new Set<String>{
        'Fuel',
        'Emergency Parts',
        'Local Tire Pickup',
        'Shop Supplies'
    };

    @AuraEnabled
    public static Integer run() {
        List<Expenses__c> records = [
            SELECT Id, Expense_Type__c
            FROM Expenses__c
            WHERE Expense_Type__c IN :VALID_CATEGORIES
            WITH SECURITY_ENFORCED
        ];
        for (Expenses__c exp : records) {
            exp.Expense_Category__c = exp.Expense_Type__c;
        }
        if (!records.isEmpty()) {
            update records;
        }
        return records.size();
    }
}
