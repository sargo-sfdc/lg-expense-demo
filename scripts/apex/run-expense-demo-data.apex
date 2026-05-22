// From project root: sf apex run --file scripts/apex/run-expense-demo-data.apex --target-org <alias>
//
// Default: up to 100 Service Resources in territory "*San Francisco" × 50 expenses each (max 5,000 rows).
// Other examples (uncomment one):
//   Integer n = ExpenseDemoDataGenerator.run('*San Francisco', 200, 50);  // cap 10k rows
//   Integer n = ExpenseDemoDataGenerator.runForAnyServiceResources(200, 50);  // no territory filter

Integer inserted = ExpenseDemoDataGenerator.run();
System.debug(LoggingLevel.INFO, 'ExpenseDemoDataGenerator inserted ' + inserted + ' rows.');
