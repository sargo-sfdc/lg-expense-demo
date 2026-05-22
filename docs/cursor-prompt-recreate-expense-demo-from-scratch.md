# Cursor prompt: recreate the Field Service “Create Expense” demo from scratch

Use this document when you want another **Solution Engineer** to reproduce the same **Field Service Mobile** pattern in **another org** using Cursor (or a similar IDE assistant).  
**Paste the prompt below into Cursor Chat or Composer** and replace the bracketed placeholders first.

---

## Before you paste: fill in these placeholders

| Placeholder | Example | Notes |
|-------------|---------|--------|
| `[ORG_CONTEXT]` | “CPQ + Field Service, US operations, USD” | Helps tailor labels and currency. |
| `[TERRITORY_OR_DATA]` | “Service territory named `Main Metro`” or “any Service Resource with Related Record = User” | Drives optional demo-data scripts. |
| `[API_OR_LABEL]` | API names must match your naming standards | e.g. `Expenses__c` vs a prefixed name. |

---

## Master prompt (copy everything in the box)

```text
You are helping build a Salesforce Field Service **demo** for a customer workshop. Implement the following **from scratch** in this Salesforce DX project (metadata API 65+ unless the project already uses a higher version).

### Business goal
Field technicians need to **log an expense on the phone** from the **Field Service mobile app** without opening a work order. Finance needs expenses stored as records for later reporting.

### Technical pattern (must follow)
1. **Custom object** (e.g. `Expenses__c` or follow project naming) with at minimum:
   - Lookup **Service_Resource__c** → `ServiceResource`
   - **Expense_Amount__c** (Currency)
   - **Expense_Date__c** (Date)
   - **Expense_Category__c** (Text or Picklist) — store category here
   - **Expense_Description__c** (Long Text)
   - **Expense_Status__c** (Picklist: Draft, Submitted, Under Review, Approved, Rejected, Paid) — optional but good for demos
   - Optional: **Expense_Number__c**, **Expense_Type__c** if useful for migration stories
2. **Apex** `ExpenseController` (with sharing):
   - `@AuraEnabled(cacheable=true) getCurrentServiceResourceId()` — query `ServiceResource` where `RelatedRecordId = :UserInfo.getUserId()`, limit 1, `WITH SECURITY_ENFORCED`
   - `@AuraEnabled createExpense(amount, expenseDate, expenseType, description, files)` — build `Expenses__c` with dynamic SObject using constants for API names at the top of the class; insert; then optionally insert up to 5 **ContentVersion** rows with `FirstPublishLocationId` = new expense Id for attachments
   - Return a small wrapper object `{ success, recordId, errorMessage }` for the LWC
   - `@AuraEnabled getLastCreatedExpenseId()` optional fallback query for mobile clients that lose the insert response
3. **LWC** `createExpense`:
   - Targets **`lightning__GlobalAction`** with **`ScreenAction`** in `createExpense.js-meta.xml`
   - Modal form: amount (use currency-friendly input), date (default to today), category combobox (values aligned with Apex), description, optional multi-file upload (max 5), Save / Cancel
   - Client-side validation: require positive amount, date, and category before Save; show saving state
   - On success, show a clear success state; optional “open record” using `NavigationMixin`
4. **Metadata for handoff**
   - **Permission set** granting: Create/Read/Edit on the expense object and FLS on written fields; Apex class access for `ExpenseController`; Read on `ServiceResource`; Create on `ContentVersion` for attachments
   - **Global QuickAction** metadata (not only manual Setup): Lightning Web Component type, `lightningWebComponent` = `createExpense` (unpackaged name — verify deploy validates when LWC is in the same deployment)
5. **Optional**: Apex `ExpenseDemoDataGenerator` with batched inserts and a cap of 10,000 rows per transaction; parameterize territory name OR a fallback “any N service resources” for orgs without a named territory
6. **Documentation** in `/docs`: short checklist for another SE — deploy `force-app`, Field Service Mobile LWC org setting, user permission “Access Lightning Web Components in Field Service Mobile”, assign permission set, add action to **Global Publisher Layout** under “Salesforce Mobile and Lightning Experience Actions”

### Constraints
- Use **Salesforce CLI (`sf`)** style project layout under `force-app/main/default/`
- Match existing project conventions if files already exist
- Keep Apex bulk-safe and security-conscious (`with sharing`, `WITH SECURITY_ENFORCED` on queries)
- Add or update **Jest tests** for the LWC if the project uses `sfdx-lwc-jest`
- Do not deploy to an org from this prompt unless the user asks; output files and commands only

### Customer / org context
[ORG_CONTEXT]

### Demo data preference
[TERRITORY_OR_DATA]

Produce the file list you created or changed, then the exact `sf project deploy start` command(s) to push to a target org alias.
```

---

## Shorter prompt (if Composer has a size limit)

```text
In this Salesforce DX repo, implement a Field Service Mobile demo: custom object Expenses__c (Service Resource lookup, amount, date, category, description, status), Apex ExpenseController (resolve ServiceResource for current user, create expense + optional ContentVersion files), LWC createExpense with lightning__GlobalAction ScreenAction, permission set + Global QuickAction metadata for createExpense, /docs handoff checklist. Use with sharing and WITH SECURITY_ENFORCED. Add Jest tests if present. Output deploy commands only, no live deploy.

Org context: [ORG_CONTEXT]
```

---

## Follow-up prompts (after the first pass)

**Deploy validation**

```text
Review the expense demo metadata for deploy order issues. List any components that must deploy together (e.g. LWC + QuickAction) and give a single sf project deploy start command for the whole force-app directory.
```

**Another SE’s org (rename object)**

```text
We need to rename the custom object from Expenses__c to CustomerExpense__c for a specific org. List every file and string that must change (Apex constants, LWC references if any, permission set, layouts). Do not change yet—produce a checklist first.
```

**Demo polish**

```text
Improve only the createExpense LWC UX for a mobile modal: default date, disable Save until required fields are valid, currency formatting for amount, saving overlay, accessible labels. Do not change Apex contracts unless required.
```

---

## What this prompt does *not* replace

Even with a perfect implementation, **each org** still needs:

- Field Service **Mobile LWC** enablement and the **Access Lightning Web Components in Field Service Mobile** (or equivalent) permission  
- **Publisher layout** assignment for the global action  
- A test user with a **Service Resource** linked to their **User**  

See [field-service-expense-demo-se-implementation-guide.md](./field-service-expense-demo-se-implementation-guide.md) for the full checklist.
