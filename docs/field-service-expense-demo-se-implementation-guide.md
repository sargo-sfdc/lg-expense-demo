# Field Service Expense Demo — SE Implementation & Duplication Guide

This document is for **Solution Engineers** who need to **reproduce, deploy, or hand off** the Field Service **Create Expense** mobile demo. It includes **step-by-step implementation**, **Salesforce CLI** commands, **metadata paths**, **org configuration**, and **Cursor** prompts you can reuse to accelerate work in this repository.

For a shorter reference on **why** the LWC is configured as a global action and Field Service Mobile constraints, see [field-service-mobile-create-expense-global-action.md](./field-service-mobile-create-expense-global-action.md).

To **recreate this solution from scratch in another org using Cursor**, see [cursor-prompt-recreate-expense-demo-from-scratch.md](./cursor-prompt-recreate-expense-demo-from-scratch.md).

---

## 1. What this demo is

| Piece | Purpose |
|--------|---------|
| **Custom object `Expenses__c`** | Stores technician expenses (amount, date, category, description, status, lookup to Service Resource, etc.). |
| **Apex `ExpenseController`** | Finds the running user’s **Service Resource** and creates `Expenses__c` rows; optional **file attachments** via `ContentVersion`. |
| **LWC `createExpense`** | Modal form (global action target `lightning__GlobalAction`, `ScreenAction`) for **Field Service Mobile**. |
| **Permission set `Field_Service_Create_Expense`** *(in repo)* | Object/FLS, `ServiceResource` read, `ContentVersion` for attachments, Apex access to `ExpenseController`. |
| **Quick action `Create_Expense`** *(in repo)* | Global action pointing at LWC `createExpense` (component reference **`createExpense`**, not `c__createExpense`, in metadata). |
| **Optional Apex** | `ExpenseDemoDataGenerator` (bulk demo rows), `ExpenseCategoryMigration` (one-time type → category copy). |

**Technician prerequisite:** a **Service Resource** whose **Related Record** is the running **User**. Without that, the UI shows an error from `getCurrentServiceResourceId()`.

---

## 2. Repository layout (what to deploy)

From the project root, relevant paths:

```
force-app/main/default/
├── objects/Expenses__c/          # Object, fields, list view
├── classes/
│   ├── ExpenseController.cls
│   ├── ExpenseDemoDataGenerator.cls
│   └── ExpenseCategoryMigration.cls
├── lwc/createExpense/            # LWC bundle
├── permissionsets/
│   └── Field_Service_Create_Expense.permissionset-meta.xml
└── quickActions/
    └── Create_Expense.quickAction-meta.xml
```

**Scripts / npm** (see `package.json`):

| Script | What it runs |
|--------|----------------|
| `npm run seed:expenses` | `scripts/apex/run-expense-demo-data.apex` → `ExpenseDemoDataGenerator.run()` |
| `npm run seed:expenses:max` | `scripts/apex/run-expense-demo-data-max.apex` (high volume, territory-dependent) |
| `npm run migrate:expense-category` | `scripts/apex/run-expense-category-migration.apex` |

---

## 3. One-pass deployment (recommended)

Authenticate to the target org (sandbox or demo):

```bash
sf org login web --alias MyDemoOrg
# Sandbox:
# sf org login web --alias MyDemoOrg --instance-url https://test.salesforce.com
sf config set target-org MyDemoOrg
```

Deploy the **entire** `force-app` package so object, Apex, LWC, permission set, and global quick action stay in sync:

```bash
cd /path/to/field-service
sf project deploy start --source-dir force-app --target-org MyDemoOrg --wait 20
```

**Validate only** (optional):

```bash
sf project deploy start --source-dir force-app --target-org MyDemoOrg --dry-run --wait 20
```

**Note:** Deploying the **QuickAction** `Create_Expense` in the same deployment as the **LWC** avoids “component not found” errors. The Lightning Web Component name in metadata is **`createExpense`** (see `Create_Expense.quickAction-meta.xml`).

**Production / coverage:** This repo may not include an Apex test class for `ExpenseController`. If your pipeline requires tests, add a test class or use org-appropriate `--test-level` flags per your standards.

---

## 4. Org configuration after deploy (still required)

These items are **not** fully replaced by metadata alone; confirm per org.

1. **Field Service Settings**  
   Enable **Lightning Web Components** / LWC support for **Field Service Mobile** (wording varies by release).

2. **User permission**  
   Ensure technicians have **Access Lightning Web Components in Field Service Mobile** (or the current equivalent), often via the Field Service permission set group.

3. **Permission set assignment**  
   Assign **`Field Service - Create Expense`** (`Field_Service_Create_Expense`) to demo users, **or** merge equivalent permissions into your standard technician permission set.

   ```bash
   sf org assign permset --name Field_Service_Create_Expense --target-org MyDemoOrg --on-behalf-of tech.user@customer.com
   ```

4. **Publisher layout**  
   **Setup → Publisher Layouts → Global Layout** (or your org’s global mobile layout) → add **`Create Expense`** to **Salesforce Mobile and Lightning Experience Actions** → Save.

5. **If you did not deploy the repo QuickAction**  
   Create the global action manually: **Setup → Global Actions → New → Lightning Web Component → `createExpense`**, then add it to the publisher layout as above.

---

## 5. Demo data (optional)

Generating rows requires **Service Territory** membership (default generator uses territory name **`*San Francisco`**) **or** use `runForAnyServiceResources` in Anonymous Apex if that territory does not exist.

```bash
npm run seed:expenses -- --target-org MyDemoOrg
# or
sf apex run --file scripts/apex/run-expense-demo-data.apex --target-org MyDemoOrg
```

Runs as the **current CLI user**; that user needs **Create** on `Expenses__c` (admin is simplest for seeding).

---

## 6. Verification checklist

| Check | How |
|--------|-----|
| Metadata present | Setup → Custom Objects → **Expenses__c**; Apex classes; Lightning Component **createExpense**. |
| Global action | Setup → Global Actions → **Create Expense** (or name you chose); type **Lightning Web Component** → **createExpense**. |
| Test user | Exactly one **Service Resource** with **Related Record** = user. |
| Mobile | Field Service app → actions menu → open form → save → new `Expenses__c` (and attachments if tested). |

---

## 7. Using Cursor in this project (non-prescriptive)

Cursor helps most when you treat the repo as the **single source of truth**: metadata, Apex, LWC, and handoff docs together.

### 7.1 Suggested Cursor prompts (copy/paste)

Use **@** to point at files or folders (e.g. `@force-app/main/default/lwc/createExpense`, `@ExpenseController.cls`) so answers stay grounded in **your** project.

**Discovery / handoff**

- *“Summarize what the createExpense LWC does for an end user, in plain language, and list what must be true in the org for it to work.”*
- *“List every metadata path a new SE must deploy for the expense demo, in dependency order.”*
- *“What is the difference between deploying only ExpenseController vs deploying the whole force-app folder?”*

**Consistency checks**

- *“Do the field API names in ExpenseController match the Expenses__c object metadata? Flag any mismatch.”*
- *“If we rename Expense_Category__c in the org, what code and metadata files must change?”*

**Org / demo prep**

- *“Write a 10-line verification checklist for a technician test user after deployment.”*
- *“Draft a short customer-safe description of this demo for a workshop agenda (no internal codenames).”*

**Small UX or copy tweaks**

- *“Update the success message in createExpense to be friendlier for a finance audience; keep mobile layout readable.”*

**Debugging (paste real errors)**

- *“Here is the deploy error: [paste]. What should I change in this repo?”*

### 7.2 What to show in a short Cursor demo (SE audience)

- One **@file** question that returns a **specific** answer from this repo (proves context, not generic chat).
- One **small cross-file change** (e.g. label copy in HTML + adjust test) with a visible **diff**—shows time saved on consistency.

Avoid long live terminal sessions unless the audience expects CLI depth.

---

## 8. Field mapping reference (Apex ↔ object)

Constants in `ExpenseController` (must match org):

| Constant | API name |
|----------|-----------|
| `EXPENSE_OBJECT` | `Expenses__c` |
| `FIELD_SERVICE_RESOURCE` | `Service_Resource__c` |
| `FIELD_AMOUNT` | `Expense_Amount__c` |
| `FIELD_DATE` | `Expense_Date__c` |
| `FIELD_CATEGORY` | `Expense_Category__c` |
| `FIELD_DESCRIPTION` | `Expense_Description__c` |

If your customer org uses different names, update the Apex constants and redeploy (or align metadata).

---

## 9. Troubleshooting (quick)

| Symptom | What to check |
|---------|----------------|
| Global action deploy fails on LWC | Deploy **LWC and QuickAction together**, or confirm `lightningWebComponent` in `Create_Expense.quickAction-meta.xml` is **`createExpense`**. |
| “No Service Resource is linked…” | Service Resource **Related Record** = User; user has read access to **ServiceResource**. |
| Action missing on phone | Publisher layout + FSL Mobile LWC setting + user permission; cache/restart app. |
| DML / FLS errors | Permission set / profile on `Expenses__c` fields; Apex class access. |
| Demo data script throws territory error | Territory **`*San Francisco`** missing or empty → use `ExpenseDemoDataGenerator.runForAnyServiceResources` in Anonymous Apex or adjust territory name in code. |

---

## 10. Summary

1. **Deploy** `force-app` to the target org.  
2. **Configure** Field Service Mobile LWC settings, user permissions, **assign** `Field_Service_Create_Expense`, **publisher layout**.  
3. **Verify** with a user that has a **Service Resource** and can create **Expenses__c**.  
4. Optionally **seed** demo data and use **Cursor** prompts above to speed handoffs and small edits.

This gives another SE a **repeatable path** to duplicate the demo without re-deriving setup from memory.
