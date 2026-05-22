import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getCurrentServiceResourceId from '@salesforce/apex/ExpenseController.getCurrentServiceResourceId';
import createExpense from '@salesforce/apex/ExpenseController.createExpense';
import getLastCreatedExpenseId from '@salesforce/apex/ExpenseController.getLastCreatedExpenseId';

export default class CreateExpense extends NavigationMixin(LightningElement) {
    @track serviceResourceId = null;
    @track loadError = null;
    @track isLoaded = false;
    @track isSubmitting = false;
    /** After submit: { success, recordId, errorMessage } so we show result in the modal. */
    @track submitResult = null;

    @track amount = '';
    @track expenseDate = '';
    @track expenseType = '';
    @track description = '';
    @track selectedFileCount = 0;
    _fileInputRef = null;

    connectedCallback() {
        this.fetchServiceResource();
    }

    todayLocalIso() {
        const d = new Date();
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    parsePositiveAmount(value) {
        if (value === null || value === undefined || value === '') {
            return null;
        }
        const cleaned = String(value).replace(/[^0-9.-]/g, '');
        if (cleaned === '' || cleaned === '-' || cleaned === '.') {
            return null;
        }
        const n = Number(cleaned);
        if (Number.isNaN(n) || n <= 0) {
            return null;
        }
        return n;
    }

    async fetchServiceResource() {
        try {
            const id = await getCurrentServiceResourceId();
            this.serviceResourceId = id;
            this.loadError = id ? null : 'No Service Resource is linked to your user.';
            if (id) {
                this.expenseDate = this.todayLocalIso();
            }
        } catch (error) {
            this.loadError = error.body?.message || error.message || 'Failed to load Service Resource.';
        } finally {
            this.isLoaded = true;
        }
    }

    get canSubmit() {
        return this.serviceResourceId && !this.isSubmitting;
    }

    get isFormValid() {
        const amt = this.parsePositiveAmount(this.amount);
        const hasDate = String(this.expenseDate || '').trim().length >= 8;
        const hasType = String(this.expenseType || '').trim().length > 0;
        return amt != null && hasDate && hasType;
    }

    get isSaveDisabled() {
        return !this.canSubmit || !this.isFormValid;
    }

    get showForm() {
        return this.isLoaded && this.serviceResourceId && !this.loadError && this.submitResult === null;
    }

    get showError() {
        return this.isLoaded && this.loadError && this.submitResult === null;
    }

    get showSpinner() {
        return !this.isLoaded;
    }

    get showSuccessPanel() {
        return this.submitResult && this.submitResult.success && this.submitResult.recordId;
    }

    get showSuccessNoIdPanel() {
        return this.submitResult && this.submitResult.success && !this.submitResult.recordId;
    }

    get showSubmitErrorPanel() {
        return this.submitResult && !this.submitResult.success && this.submitResult.errorMessage;
    }

    get savedRecordId() {
        return (this.submitResult && this.submitResult.recordId) || '';
    }

    get expenseTypeOptions() {
        return [
            { label: 'Fuel', value: 'Fuel' },
            { label: 'Emergency Parts', value: 'Emergency Parts' },
            { label: 'Local Tire Pickup', value: 'Local Tire Pickup' },
            { label: 'Shop Supplies', value: 'Shop Supplies' }
        ];
    }

    handleAmountChange(event) {
        this.amount = event.detail?.value ?? event.target?.value ?? '';
    }

    handleDateChange(event) {
        this.expenseDate = event.detail?.value ?? event.target?.value ?? '';
    }

    handleTypeChange(event) {
        this.expenseType = event.detail?.value || event.target?.value || '';
    }

    handleDescriptionChange(event) {
        this.description = event.detail?.value ?? event.target?.value ?? '';
    }

    handleFileChange(event) {
        const input = event.target;
        this._fileInputRef = input;
        this.selectedFileCount = input.files ? input.files.length : 0;
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = reader.result;
                const base64 = result.indexOf(',') >= 0 ? result.split(',')[1] : result;
                resolve({ title: file.name, base64Data: base64, mimeType: file.type || 'application/octet-stream' });
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    async handleSubmit() {
        if (!this.canSubmit || !this.isFormValid) {
            return;
        }
        this.isSubmitting = true;
        this.submitResult = null;
        try {
            let filesParam = null;
            const fileInput = this.template.querySelector('input[type="file"]');
            if (fileInput && fileInput.files && fileInput.files.length > 0) {
                const fileList = Array.from(fileInput.files).slice(0, 5);
                filesParam = await Promise.all(fileList.map((file) => this.readFileAsBase64(file)));
            }
            const amt = this.parsePositiveAmount(this.amount);
            const amountForApex = amt != null ? String(amt) : null;
            const response = await createExpense({
                amount: amountForApex,
                expenseDate: this.expenseDate || null,
                expenseType: this.expenseType || null,
                description: this.description || null,
                files: filesParam
            });
            const data = response?.result ?? response;
            let recordId = (data && (data.recordId || data.RecordId)) || null;
            if (!recordId || String(recordId).length < 10) {
                try {
                    const lastId = await getLastCreatedExpenseId();
                    if (lastId && lastId.length > 10) {
                        recordId = lastId;
                    }
                } catch (_) {
                    // ignore
                }
            }
            if (data && data.success) {
                this.submitResult = {
                    success: true,
                    recordId: recordId || '',
                    errorMessage: null
                };
                if (recordId) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Expense saved.',
                            variant: 'success'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Saved',
                            message: 'Expense saved. If you don\'t see it, check the list or run a report.',
                            variant: 'warning',
                            mode: 'sticky'
                        })
                    );
                }
            } else {
                const errorMessage =
                    (data && data.errorMessage) || (response && response.errorMessage) || 'Could not save expense.';
                this.submitResult = { success: false, recordId: null, errorMessage };
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Saving Expense',
                        message: errorMessage,
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            }
        } catch (error) {
            const message =
                error.body?.message ||
                (Array.isArray(error.body?.pageErrors) && error.body.pageErrors[0]?.message) ||
                error.message ||
                'Could not save expense.';
            this.submitResult = { success: false, recordId: null, errorMessage: message };
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Saving Expense',
                    message,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    handleViewRecord() {
        const id = this.savedRecordId;
        if (!id || id.length < 10) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCloseResult() {
        this.submitResult = null;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
