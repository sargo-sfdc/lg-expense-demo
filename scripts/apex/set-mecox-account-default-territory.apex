// Step 8d: Point Mecox Estate at South Fork - West default Service Territory (run after field deploy).
Id swtId = [SELECT Id FROM ServiceTerritory WHERE Name = 'South Fork - West' LIMIT 1].Id;
Account mecox = [SELECT Id FROM Account WHERE Name = 'Mecox Estate' LIMIT 1];
mecox.LG_Default_Service_Territory__c = swtId;
update mecox;
System.debug('LG_Default_Service_Territory__c=' + swtId);
