// Maximum volume in one transaction (10,000 Expenses__c rows): 200 resources × 50 expenses.
// Requires at least 200 Service Resources with RelatedRecordId in the territory.
// sf apex run --file scripts/apex/run-expense-demo-data-max.apex --target-org <alias>

Integer inserted = ExpenseDemoDataGenerator.run('*San Francisco', 200, 50);
System.debug(LoggingLevel.INFO, 'ExpenseDemoDataGenerator (max) inserted ' + inserted + ' rows.');
