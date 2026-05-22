jest.mock(
    'lightning/actions',
    () => ({
        CloseActionScreenEvent: class CloseActionScreenEvent extends CustomEvent {
            constructor() {
                super('lightning__closeactionscreen');
            }
        }
    }),
    { virtual: true }
);

import { createElement } from 'lwc';
import CreateExpense from 'c/createExpense';

import getCurrentServiceResourceId from '@salesforce/apex/ExpenseController.getCurrentServiceResourceId';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import getLastCreatedExpenseId from '@salesforce/apex/ExpenseController.getLastCreatedExpenseId';

jest.mock(
    '@salesforce/apex/ExpenseController.getCurrentServiceResourceId',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/ExpenseController.createExpense',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/ExpenseController.getLastCreatedExpenseId',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

async function flushPromises() {
    return Promise.resolve();
}

describe('c-createExpense', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('shows spinner while loading', () => {
        getCurrentServiceResourceId.mockReturnValue(new Promise(() => {}));
        const el = createElement('c-create-expense', { is: CreateExpense });
        document.body.appendChild(el);
        return Promise.resolve().then(() => {
            const spinner = el.shadowRoot.querySelector('lightning-spinner');
            expect(spinner).toBeTruthy();
        });
    });

    it('shows form when Service Resource is resolved', async () => {
        getCurrentServiceResourceId.mockResolvedValue('0Hox00000000001');
        const el = createElement('c-create-expense', { is: CreateExpense });
        document.body.appendChild(el);
        await flushPromises();
        await flushPromises();
        const inputs = el.shadowRoot.querySelectorAll('lightning-input');
        expect(inputs.length).toBeGreaterThanOrEqual(2);
    });

    it('disables Save until amount, date, and category are set', async () => {
        getCurrentServiceResourceId.mockResolvedValue('0Hox00000000001');
        const el = createElement('c-create-expense', { is: CreateExpense });
        document.body.appendChild(el);
        await flushPromises();
        await flushPromises();
        const saveBtn = [...el.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === 'Save');
        expect(saveBtn.disabled).toBe(true);
    });

    it('shows error when no Service Resource', async () => {
        getCurrentServiceResourceId.mockResolvedValue(null);
        const el = createElement('c-create-expense', { is: CreateExpense });
        document.body.appendChild(el);
        await flushPromises();
        await flushPromises();
        const alert = el.shadowRoot.querySelector('[role="alert"]');
        expect(alert).toBeTruthy();
        expect(alert.textContent).toContain('No Service Resource');
    });

    it('calls createExpense and shows success panel on submit', async () => {
        getCurrentServiceResourceId.mockResolvedValue('0Hox00000000001');
        createExpense.mockResolvedValue({
            success: true,
            recordId: 'a0Xxx000001',
            message: 'Expense saved. Record ID: a0Xxx000001'
        });
        getLastCreatedExpenseId.mockResolvedValue(null);
        const el = createElement('c-create-expense', { is: CreateExpense });
        document.body.appendChild(el);
        await flushPromises();
        await flushPromises();

        const inputs = el.shadowRoot.querySelectorAll('lightning-input');
        inputs[0].dispatchEvent(new CustomEvent('change', { detail: { value: '42.50' } }));
        inputs[1].dispatchEvent(new CustomEvent('change', { detail: { value: '2025-04-20' } }));

        const combo = el.shadowRoot.querySelector('lightning-combobox');
        combo.dispatchEvent(new CustomEvent('change', { detail: { value: 'Fuel' } }));

        await flushPromises();

        const saveBtn = [...el.shadowRoot.querySelectorAll('lightning-button')].find((b) => b.label === 'Save');
        expect(saveBtn.disabled).toBe(false);
        saveBtn.click();
        await flushPromises();
        await flushPromises();
        expect(createExpense).toHaveBeenCalledWith({
            amount: '42.5',
            expenseDate: '2025-04-20',
            expenseType: 'Fuel',
            description: null,
            files: null
        });
        const successAlert = el.shadowRoot.querySelector('.slds-alert_success');
        expect(successAlert).toBeTruthy();
        expect(successAlert.textContent).toContain('Expense logged');
    });

    it('Cancel dispatches close action and does not call createExpense', async () => {
        getCurrentServiceResourceId.mockResolvedValue('0Hox00000000001');
        const el = createElement('c-create-expense', { is: CreateExpense });
        const dispatchSpy = jest.spyOn(el, 'dispatchEvent');
        document.body.appendChild(el);
        await flushPromises();
        await flushPromises();
        const cancelBtn = [...el.shadowRoot.querySelectorAll('lightning-button')].find(
            (b) => b.label === 'Cancel'
        );
        cancelBtn.click();
        expect(dispatchSpy).toHaveBeenCalled();
        expect(createExpense).not.toHaveBeenCalled();
    });
});
