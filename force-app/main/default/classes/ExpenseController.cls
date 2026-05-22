/**
 * Controller for createExpense LWC (Field Service mobile global action).
 * Resolves current user's Service Resource and creates expense records via dynamic SObject.
 *
 * To ensure the global action creates records:
 * 1. In Setup → Object Manager → Expenses__c, confirm these field API names exist and match the constants below:
 *    - Lookup to Service Resource (e.g. Service_Resource__c)
 *    - Amount, Date, Category, Description (e.g. Expense_Amount__c, Expense_Date__c, Expense_Category__c, Expense_Description__c)
 * 2. If your object uses different names, update the constants in this class and redeploy.
 * 3. Ensure the running user has Create permission on Expenses__c and access to the Service Resource.
 */
public with sharing class ExpenseController {
    /** Result shape for createExpense so LWC gets a predictable recordId in the response. */
    public class CreateExpenseResult {
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String errorMessage;
    }

    /** File attachment for createExpense. LWC sends base64-encoded content. */
    public class FileInput {
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String base64Data;
        @AuraEnabled
        public String mimeType;
    }

    private static final String EXPENSE_OBJECT = 'Expenses__c';
    private static final String FIELD_SERVICE_RESOURCE = 'Service_Resource__c';
    private static final String FIELD_AMOUNT = 'Expense_Amount__c';
    private static final String FIELD_DATE = 'Expense_Date__c';
    private static final String FIELD_CATEGORY = 'Expense_Category__c';
    private static final String FIELD_DESCRIPTION = 'Expense_Description__c';

    /**
     * Returns the Id of the most recently created Expenses__c for the current user's Service Resource
     * (created in the last 2 minutes). Use after createExpense when the client cannot rely on the return value.
     * @return Record Id as String, or null if none found
     */
    @AuraEnabled
    public static String getLastCreatedExpenseId() {
        Id resourceId = getCurrentServiceResourceId();
        if (resourceId == null) {
            return null;
        }
        DateTime since = DateTime.now().addMinutes(-2);
        String soql =
            'SELECT Id FROM ' +
            EXPENSE_OBJECT +
            ' WHERE ' +
            FIELD_SERVICE_RESOURCE +
            ' = :resourceId AND CreatedDate >= :since ORDER BY CreatedDate DESC LIMIT 1';
        List<SObject> rows = Database.query(soql);
        if (rows.isEmpty()) {
            return null;
        }
        return String.valueOf(rows[0].get('Id'));
    }

    /**
     * Returns the Service Resource Id linked to the current user.
     * Used to set context for new expense records (no Work Order / Service Appointment).
     * @return Service Resource Id, or null if none found
     */
    @AuraEnabled(cacheable=true)
    public static Id getCurrentServiceResourceId() {
        Id userId = UserInfo.getUserId();
        List<ServiceResource> resources = [
            SELECT Id
            FROM ServiceResource
            WHERE RelatedRecordId = :userId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return resources.isEmpty() ? null : resources[0].Id;
    }

    /**
     * Creates a new expense record for the current user's Service Resource.
     * Returns a result object so the mobile app always receives a clear error message.
     * @param amount Expense amount (stored as string from form)
     * @param expenseDate Date of expense (ISO date string)
     * @param expenseType Category of expense (stored in Expense_Category__c)
     * @param description Optional description
     * @param files Optional list of file attachments (title, base64Data, mimeType); max 5 files, linked to the new expense
     * @return CreateExpenseResult with success, recordId, and errorMessage for reliable LWC serialization
     */
    @AuraEnabled
    public static CreateExpenseResult createExpense(
        String amount,
        String expenseDate,
        String expenseType,
        String description,
        List<FileInput> files
    ) {
        CreateExpenseResult result = new CreateExpenseResult();

        try {
            Id serviceResourceId = getCurrentServiceResourceId();
            if (serviceResourceId == null) {
                result.success = false;
                result.errorMessage = 'No Service Resource is linked to your user. Contact your administrator.';
                return result;
            }

            Schema.SObjectType expenseTypeDesc = Schema.getGlobalDescribe().get(EXPENSE_OBJECT);
            if (expenseTypeDesc == null) {
                result.success = false;
                result.errorMessage = 'Expense object (' + EXPENSE_OBJECT + ') is not available. Update ExpenseController constants.';
                return result;
            }

            SObject expense = expenseTypeDesc.newSObject();
            expense.put(FIELD_SERVICE_RESOURCE, serviceResourceId);

            if (String.isNotBlank(amount)) {
                expense.put(FIELD_AMOUNT, Decimal.valueOf(amount.trim()));
            }
            if (String.isNotBlank(expenseDate)) {
                expense.put(FIELD_DATE, Date.valueOf(expenseDate));
            }
            if (String.isNotBlank(expenseType)) {
                expense.put(FIELD_CATEGORY, expenseType.trim());
            }
            if (String.isNotBlank(description)) {
                expense.put(FIELD_DESCRIPTION, description.trim());
            }

            insert expense;
            Id newId = (Id) expense.get('Id');
            if (newId == null) {
                result.success = false;
                result.errorMessage = 'Record was created but no Id was returned. Check triggers and sharing.';
                return result;
            }
            if (files != null && !files.isEmpty()) {
                Integer maxFiles = 5;
                for (Integer i = 0; i < Math.min(files.size(), maxFiles); i++) {
                    FileInput fi = files[i];
                    if (fi == null || String.isBlank(fi.base64Data)) {
                        continue;
                    }
                    String fileName = String.isNotBlank(fi.title) ? fi.title : 'attachment_' + i;
                    ContentVersion cv = new ContentVersion();
                    cv.Title = fileName;
                    cv.PathOnClient = fileName;
                    cv.VersionData = EncodingUtil.base64Decode(fi.base64Data);
                    cv.FirstPublishLocationId = newId;
                    insert cv;
                }
            }
            result.success = true;
            result.recordId = String.valueOf(newId);
            result.message = 'Expense saved. Record ID: ' + result.recordId;
            return result;
        } catch (DmlException e) {
            String msg = e.getDmlMessage(0);
            if (e.getNumDml() > 0 && e.getDmlFieldNames(0) != null && !e.getDmlFieldNames(0).isEmpty()) {
                msg += ' Fields: ' + String.join(e.getDmlFieldNames(0), ', ');
            }
            result.success = false;
            result.errorMessage = msg;
            return result;
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Unexpected error: ' + e.getMessage();
            return result;
        }
    }
}
