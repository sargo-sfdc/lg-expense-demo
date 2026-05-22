# Field Service Mobile: Create Expense Global Action

> **Full SE duplication guide (deploy paths, permission set, QuickAction metadata, Cursor prompts):**  
> [field-service-expense-demo-se-implementation-guide.md](./field-service-expense-demo-se-implementation-guide.md)

This guide documents how the **Create Expense** experience is wired for the **Field Service mobile app** and how another Solution Engineer can **deploy and finish configuration** in a target org.

The implementation is:

- **LWC** `createExpense` — exposed as a **Lightning Web Component Global Action** (screen modal).
- **Apex** `ExpenseController` — resolves the technician’s **Service Resource** and inserts **Expenses__c** (and optional file attachments).

Metadata lives under `force-app/main/default/` (see paths in [Metadata to deploy](#metadata-to-deploy)).

---

## What you are building (conceptually)

1. **Deploy** the custom object, Apex, and LWC so the org has the data model and the `c:createExpense` component.
2. **Turn on** Field Service Mobile support for **Lightning Web Components** (org setting + user permission).
3. **Register** a **Global Action** in Setup that points at the LWC.
4. **Surface** that global action on the **global publisher layout** so it appears in the **Field Service** mobile app action menu.

The LWC bundle is already configured for global actions:

```1:13:force-app/main/default/lwc/createExpense/createExpense.js-meta.xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>65.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightning__GlobalAction</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__GlobalAction">
            <actionType>ScreenAction</actionType>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

`ScreenAction` opens the component in a **modal** (appropriate for a data-entry form).

---

## Prerequisites

| Requirement | Why |
|-------------|-----|
| **Field Service** licensed and configured | Mobile app and Service Resource model. |
| **Service Resource** with **Related Record** = running user | `ExpenseController.getCurrentServiceResourceId()` queries `ServiceResource` where `RelatedRecordId` is the current user. Technicians without this link see *“No Service Resource is linked to your user.”* |
| **Expenses__c** (or equivalent) with fields matching Apex constants | See [Expense object and field mapping](#expense-object-and-field-mapping). |
| **Create** on `Expenses__c` (profile or permission set) | Insert fails without object permission. |
| **Apex class access** for `ExpenseController` | Grant via profile or permission set (`Apex Class Access`). |

---

## Org settings and permissions (Field Service Mobile + LWC)

These steps are **not** fully represented as metadata in this repo; they must be applied per org.

1. **Enable Lightning Web Components in Field Service Mobile**  
   In Setup, open **Field Service Settings** (wording can vary slightly by release). Enable the option to use **Lightning / LWC** in the Field Service mobile app (often labeled along the lines of enabling the **Lightning SDK** or **Lightning Web Components** for Field Service Mobile).  
   If this is off, global actions backed by LWCs will not behave as expected in the technician app.

2. **Grant users permission to run LWCs in Field Service Mobile**  
   Add the permission whose label is typically **Access Lightning Web Components in Field Service Mobile** to the **Field Service Technician** (or equivalent) **permission set group / permission set**.  
   Confirm in the target org under the permission set’s **App Permissions** or **System Permissions** section.

3. **Mobile publisher**  
   After the global action exists, it must appear in the **Salesforce Mobile and Lightning Experience Actions** section of the relevant **Publisher Layout** (see below). That is what makes the action available in the mobile action menu for Field Service.

> **Tip:** If the action appears in Salesforce Mobile but not Field Service, recheck Field Service–specific LWC settings and the publisher layout assignment for the app context your technicians use.

---

## Metadata to deploy

Deploy at minimum:

| Type | Path |
|------|------|
| Custom object + fields | `force-app/main/default/objects/Expenses__c/` |
| Apex | `force-app/main/default/classes/ExpenseController.cls` (+ `ExpenseController.cls-meta.xml`) |
| LWC | `force-app/main/default/lwc/createExpense/` |

Optional (demo / one-time data, not required for the button itself):

- `ExpenseDemoDataGenerator`, `ExpenseCategoryMigration`, and scripts under `scripts/apex/` (see `package.json` npm scripts `seed:expenses` and `migrate:expense-category`).

### Suggested CLI deploy (from repo root)

Authenticate and set the target org (`sf org login web`, `sf config set target-org <alias>`), then:

```bash
sf project deploy start \
  --source-dir force-app/main/default/objects/Expenses__c \
  --source-dir force-app/main/default/classes/ExpenseController.cls \
  --source-dir force-app/main/default/classes/ExpenseController.cls-meta.xml \
  --source-dir force-app/main/default/lwc/createExpense
```

Alternatively deploy the whole `force-app` tree if this package is the source of truth for the org.

After deploy, run **local tests** if your pipeline requires them, for example:

```bash
sf apex run test --tests ExpenseControllerTest --result-format human
```

*(Add a test class in the project if the org’s coverage policy requires it; there may not be one in-repo yet.)*

---

## Expense object and field mapping

`ExpenseController` uses **dynamic field API names** (constants at the top of the class). They must exist in the org and be readable/writable for the running user.

```35:40:force-app/main/default/classes/ExpenseController.cls
    private static final String EXPENSE_OBJECT = 'Expenses__c';
    private static final String FIELD_SERVICE_RESOURCE = 'Service_Resource__c';
    private static final String FIELD_AMOUNT = 'Expense_Amount__c';
    private static final String FIELD_DATE = 'Expense_Date__c';
    private static final String FIELD_CATEGORY = 'Expense_Category__c';
    private static final String FIELD_DESCRIPTION = 'Expense_Description__c';
```

**Important for deployers:** This repository’s object metadata includes **`Expense_Type__c`** but the controller writes the category value to **`Expense_Category__c`**. Before go-live, either:

- Create **`Expense_Category__c`** in the org (and deploy it), **or**
- Change `FIELD_CATEGORY` to match your org’s field (for example `Expense_Type__c`) and redeploy.

If you use both fields historically, the repo includes an optional **Apex migration** (`ExpenseCategoryMigration`) and script `npm run migrate:expense-category` to copy valid values from type to category—run only after `Expense_Category__c` exists.

---

## Manual setup: create the Global Action (UI)

These steps register the LWC as a **global** quick action. Exact labels can vary by release; use Quick Find if needed.

1. In **Setup**, search for **Global Actions** (sometimes under **User Interface**).
2. Click **New Action**.
3. **Action Type:** **Lightning Web Component**.
4. **Lightning Web Component:** choose **`createExpense`** (API name `c:createExpense` in managed contexts may differ if namespaced).
5. Set **Label** (e.g. `Create Expense`), **Name** (unique, no spaces), and optionally **Icon**.
6. Save.

You cannot change the **action type** (e.g. Screen vs headless) after creation; this project uses a **screen** action by design.

---

## Manual setup: add the action to the mobile publisher

1. In **Setup**, search for **Publisher Layouts**.
2. Open the **Global Layout** (or the layout your org uses for **global** actions on mobile—confirm with your app standards).
3. Edit the layout.
4. In the palette, find your new **Create Expense** action.
5. Add it to the **Salesforce Mobile and Lightning Experience Actions** section (order determines how it appears in the mobile action launcher).
6. Save.

Technicians must use an **app / profile** that uses this publisher layout (or inherit it) for the action to show.

---

## Verification checklist

| Step | Pass criteria |
|------|----------------|
| Metadata deploy | No errors; LWC and Apex visible in Setup. |
| Service Resource | Test user has exactly one `ServiceResource` with `RelatedRecordId` = that user (or adjust test data). |
| Object security | User can **Create** `Expenses__c` and **Edit** fields being written. |
| Apex access | `ExpenseController` allowed for the user’s profile or permission set. |
| FSL LWC permission | User has **Access Lightning Web Components in Field Service Mobile** (or current equivalent). |
| Global action | Action exists and references `createExpense`. |
| Publisher layout | Action is in **Mobile and Lightning Experience Actions**. |
| Device | Open **Field Service** mobile app as the test user; open the **actions** menu; run **Create Expense**; submit a minimal row; confirm a new `Expenses__c` Id and optional attachments. |

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Action not listed when creating Global Action | LWC not deployed, not **exposed**, or missing `lightning__GlobalAction` target. |
| Action not on phone | Not on publisher layout, or wrong layout for the user’s app; or mobile cache—have user refresh / reinstall if needed. |
| “No Service Resource is linked to your user” | No `ServiceResource` row for the user, or `RelatedRecordId` is not the User Id. |
| DML errors on save | Field level security, validation rules, missing **`Expense_Category__c`**, or required fields on `Expenses__c` not populated by the form. |
| Blank / broken screen in FSL app | Field Service Mobile LWC org setting off, or user missing FSL LWC permission. |

---

## Reference: Salesforce documentation

- [Configure Lightning Web Components as Global Actions](https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-global-action.html) — `lightning__GlobalAction` and `ScreenAction`.
- Field Service Mobile LWC enablement and permissions: use **Help** in your org for the current **Field Service Settings** and permission labels for your edition/release.

---

## Summary for handoff

1. Deploy **Expenses__c**, **ExpenseController**, **createExpense** LWC.  
2. Align **`Expense_Category__c`** (or change the Apex constant).  
3. Enable **LWC in Field Service Mobile** and assign **Access Lightning Web Components in Field Service Mobile** (or release-equivalent).  
4. Create **Global Action** → **Lightning Web Component** → `createExpense`.  
5. Add the action to **Publisher Layout** → **Salesforce Mobile and Lightning Experience Actions**.  
6. Verify with a user that has a **Service Resource** and **Create** on **Expenses__c**.

Following the above gives a repeatable path another Solution Engineer can use in sandbox or production without guessing the Field Service–specific toggles or the publisher layout step.
