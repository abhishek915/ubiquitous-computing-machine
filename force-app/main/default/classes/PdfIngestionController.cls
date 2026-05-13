public with sharing class PdfIngestionController {
    public class PdfUploadResponse {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id parsedDocumentId;
        @AuraEnabled public String extractedText;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public String invoiceDate;
        @AuraEnabled public String totalAmount;
        @AuraEnabled public String vendorName;
        @AuraEnabled public String customerName;
        @AuraEnabled public String parsingStatus;
    }

    @AuraEnabled
    public static PdfUploadResponse uploadAndProcessPdf(String fileName, String base64Data, Id firstPublishLocationId) {
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('File name and file data are required.');
        }
        if (!fileName.toLowerCase().endsWith('.pdf')) {
            throw new AuraHandledException('Only PDF files are supported.');
        }

        Blob pdfBlob;
        try {
            pdfBlob = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('Could not decode uploaded PDF content.');
        }

        ContentVersion version = new ContentVersion();
        version.PathOnClient = fileName;
        version.Title = fileName.toLowerCase().endsWith('.pdf')
            ? fileName.substring(0, fileName.length() - 4)
            : fileName;
        version.VersionData = pdfBlob;
        if (firstPublishLocationId != null) {
            version.FirstPublishLocationId = firstPublishLocationId;
        }
        insert version;

        ContentVersion storedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
            LIMIT 1
        ];

        String extractedText = extractTextFromPdf(pdfBlob);
        Map<String, String> parsedFields = parseFields(extractedText);

        Parsed_Document__c parsedDocument = new Parsed_Document__c(
            Source_File_Name__c = fileName,
            ContentVersionId__c = storedVersion.Id,
            Extracted_Text__c = extractedText,
            Invoice_Number__c = parsedFields.get('invoiceNumber'),
            Invoice_Date_Raw__c = parsedFields.get('invoiceDateRaw'),
            Total_Amount__c = parseDecimal(parsedFields.get('totalAmount')),
            Vendor_Name__c = parsedFields.get('vendorName'),
            Customer_Name__c = parsedFields.get('customerName'),
            Parsing_Status__c = parsedFields.get('parsingStatus')
        );
        insert parsedDocument;

        PdfUploadResponse response = new PdfUploadResponse();
        response.contentVersionId = storedVersion.Id;
        response.contentDocumentId = storedVersion.ContentDocumentId;
        response.parsedDocumentId = parsedDocument.Id;
        response.extractedText = extractedText;
        response.invoiceNumber = parsedFields.get('invoiceNumber');
        response.invoiceDate = parsedFields.get('invoiceDateRaw');
        response.totalAmount = parsedFields.get('totalAmount');
        response.vendorName = parsedFields.get('vendorName');
        response.customerName = parsedFields.get('customerName');
        response.parsingStatus = parsedFields.get('parsingStatus');
        return response;
    }

    private static Map<String, String> parseFields(String sourceText) {
        Map<String, String> output = new Map<String, String>();
        String text = String.isBlank(sourceText) ? '' : sourceText;

        output.put('invoiceNumber', extractPattern(text, '(?i)invoice\\s*(?:no|number|#)?\\s*[:#-]?\\s*([A-Z0-9\\-/]+)'));
        output.put('invoiceDateRaw', extractPattern(text, '(?i)invoice\\s*date\\s*[:#-]?\\s*([0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}|[0-9]{4}-[0-9]{2}-[0-9]{2})'));
        output.put('totalAmount', extractPattern(text, '(?i)total\\s*(?:amount|due)?\\s*[:#-]?\\s*\\$?([0-9,]+(?:\\.[0-9]{2})?)'));
        output.put(
            'vendorName',
            extractPattern(
                text,
                '(?i)(?:vendor|seller|from)\\s*[:#-]\\s*([A-Za-z0-9 &.,\\-]+?)(?=\\s+(?:bill\\s*to|customer|client|invoice|total)\\b|$)'
            )
        );
        output.put(
            'customerName',
            extractPattern(
                text,
                '(?i)(?:bill\\s*to|customer|client)\\s*[:#-]\\s*([A-Za-z0-9 &.,\\-]+?)(?=\\s+(?:invoice|total|vendor|seller|from)\\b|$)'
            )
        );

        Integer matches = 0;
        for (String key : new List<String>{'invoiceNumber', 'invoiceDateRaw', 'totalAmount', 'vendorName', 'customerName'}) {
            if (!String.isBlank(output.get(key))) {
                matches++;
            }
        }
        output.put('parsingStatus', matches > 0 ? 'Parsed' : 'No structured fields matched');
        return output;
    }

    private static String extractPattern(String sourceText, String regex) {
        if (String.isBlank(sourceText)) {
            return null;
        }
        Pattern p = Pattern.compile(regex);
        Matcher m = p.matcher(sourceText);
        if (m.find()) {
            return m.group(1) != null ? m.group(1).trim() : null;
        }
        return null;
    }

    private static Decimal parseDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.replace(',', '');
        try {
            return Decimal.valueOf(normalized);
        } catch (Exception e) {
            return null;
        }
    }

    private static String extractTextFromPdf(Blob pdfBlob) {
        if (pdfBlob == null) {
            return '';
        }

        String textFromBlob = '';
        try {
            textFromBlob = pdfBlob.toString();
        } catch (Exception e) {
            textFromBlob = '';
        }

        String merged = textFromBlob;
        merged = merged.replaceAll('[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]', ' ');
        merged = merged.replaceAll('\\s+', ' ').trim();
        if (merged.length() > 130000) {
            return merged.substring(0, 130000);
        }
        return merged;
    }
}
