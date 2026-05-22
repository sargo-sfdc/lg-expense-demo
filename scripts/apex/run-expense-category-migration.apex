// Run from project root: npm run migrate:expense-category
// Or: sf apex run --file scripts/apex/run-expense-category-migration.apex
// Copies Expense_Type__c to Expense_Category__c for all records with valid category values.
Integer count = ExpenseCategoryMigration.run();
System.debug('ExpenseCategoryMigration: updated ' + count + ' expense record(s).');
