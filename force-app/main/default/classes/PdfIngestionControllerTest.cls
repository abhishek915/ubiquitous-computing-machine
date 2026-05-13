@IsTest
private class PdfIngestionControllerTest {
    @IsTest
    static void uploadAndParsePdf_savesContentAndParsedRecord() {
        String samplePdfLikeText = '%PDF-1.4 Invoice Number: INV-1001 Invoice Date: 01/31/2026 '
            + 'Total Amount: $1234.56 Vendor: Acme Supplies Customer: Globex Corp %%EOF';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(samplePdfLikeText));

        Test.startTest();
        PdfIngestionController.PdfUploadResponse response =
            PdfIngestionController.uploadAndProcessPdf('invoice.pdf', base64Data, null);
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertNotEquals(null, response.contentVersionId);
        System.assertNotEquals(null, response.contentDocumentId);
        System.assertNotEquals(null, response.parsedDocumentId);
        System.assertEquals('INV-1001', response.invoiceNumber);
        System.assertEquals('01/31/2026', response.invoiceDate);
        System.assertEquals('1234.56', response.totalAmount);

        Parsed_Document__c record = [
            SELECT Source_File_Name__c, Invoice_Number__c, Invoice_Date_Raw__c,
                Total_Amount__c, Vendor_Name__c, Customer_Name__c, Parsing_Status__c
            FROM Parsed_Document__c
            WHERE Id = :response.parsedDocumentId
            LIMIT 1
        ];

        System.assertEquals('invoice.pdf', record.Source_File_Name__c);
        System.assertEquals('INV-1001', record.Invoice_Number__c);
        System.assertEquals('01/31/2026', record.Invoice_Date_Raw__c);
        System.assertEquals(1234.56, record.Total_Amount__c);
        System.assertEquals('Acme Supplies', record.Vendor_Name__c);
        System.assertEquals('Globex Corp', record.Customer_Name__c);
        System.assertEquals('Parsed', record.Parsing_Status__c);
    }

    @IsTest
    static void uploadAndParsePdf_rejectsNonPdf() {
        Boolean failed = false;
        try {
            PdfIngestionController.uploadAndProcessPdf(
                'notes.txt',
                EncodingUtil.base64Encode(Blob.valueOf('hello')),
                null
            );
        } catch (AuraHandledException e) {
            failed = true;
            System.assert(e.getMessage().contains('Only PDF files are supported.'));
        }
        System.assertEquals(true, failed);
    }
}
