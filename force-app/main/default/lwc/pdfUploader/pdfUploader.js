import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadAndProcessPdf from '@salesforce/apex/PdfIngestionController.uploadAndProcessPdf';

export default class PdfUploader extends LightningElement {
    @api recordId;
    @track result;

    fileName;
    fileBase64;
    isLoading = false;

    get acceptedFormats() {
        return ['.pdf'];
    }

    get isUploadDisabled() {
        return this.isLoading || !this.fileBase64;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        this.result = null;

        if (!file) {
            this.fileName = null;
            this.fileBase64 = null;
            return;
        }

        if (!file.name.toLowerCase().endsWith('.pdf')) {
            this.showToast('Invalid file', 'Please select a PDF file only.', 'error');
            this.fileName = null;
            this.fileBase64 = null;
            return;
        }

        this.fileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = reader.result;
            const commaIndex = dataUrl.indexOf(',');
            this.fileBase64 = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : null;
        };
        reader.onerror = () => {
            this.showToast('Read error', 'Could not read the selected file.', 'error');
            this.fileName = null;
            this.fileBase64 = null;
        };
        reader.readAsDataURL(file);
    }

    async handleUpload() {
        if (!this.fileBase64) {
            this.showToast('Missing file', 'Select a PDF before uploading.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const response = await uploadAndProcessPdf({
                fileName: this.fileName,
                base64Data: this.fileBase64,
                firstPublishLocationId: this.recordId || null
            });
            this.result = response;
            this.showToast('Success', 'PDF uploaded and processed.', 'success');
        } catch (error) {
            this.showToast('Error', this.normalizeError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        return 'Unexpected error while processing the PDF.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
