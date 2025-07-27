import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';
import * as os from 'os';
import * as fs from 'fs';
import * as path from 'path';

admin.initializeApp();
const storage = admin.storage();

export const generateQuotePdf = functions.https.onCall(async (request, context) => {


    const { docId, orgId } = request.data;

    // Input validation
    if (!docId || !orgId) {
        throw new functions.https.HttpsError('invalid-argument', 'docId and orgId are required');
    }





    try {


        // Get quote data
        const quoteRef = admin.firestore()
            .collection('quotes')
            .doc(docId);

        const quoteSnap = await quoteRef.get();
        if (!quoteSnap.exists) {
            throw new functions.https.HttpsError('not-found', 'Quote not found');
        }

        const quote = quoteSnap.data();
        if (!quote) {
            throw new functions.https.HttpsError('data-loss', 'Quote data missing');
        }

        // Create a new PDF document
        const pdfDoc = await PDFDocument.create();

        // Register fontkit instance

        // Embed fonts (Helvetica is standard PDF font)
        const font = await pdfDoc.embedFont(StandardFonts.Helvetica);

        // Add a new page
        const page = pdfDoc.addPage([595, 842]); // A4 size in points (595 × 842 points)
        const { height } = page.getSize();

        // Draw header
        page.drawText('QUOTE', {
            x: 50,
            y: height - 50,
            size: 24,
            font,
            color: rgb(0, 0, 0),
        });

        // Draw quote information
        let yPosition = height - 100;

        page.drawText(`Quote #: ${docId}`, {
            x: 50,
            y: yPosition,
            size: 12,
            font,
        });
        yPosition -= 20;

        page.drawText(`Date: ${quote.createdAt}`, {
            x: 50,
            y: yPosition,
            size: 12,
            font,
        });
        yPosition -= 40;

        // Draw customer information
        page.drawText('BILL TO:', {
            x: 50,
            y: yPosition,
            size: 14,
            font,
        });
        yPosition -= 20;

        page.drawText(quote.clientName, {
            x: 50,
            y: yPosition,
            size: 12,
            font,
        });
        yPosition -= 15;


        // Draw line items table
        yPosition -= 30;
        page.drawText('ITEMS', {
            x: 50,
            y: yPosition,
            size: 14,
            font,
        });
        yPosition -= 20;

        // Table header
        page.drawText('Description', { x: 50, y: yPosition, size: 12, font });
        page.drawText('Qty', { x: 300, y: yPosition, size: 12, font });
        page.drawText('Price', { x: 350, y: yPosition, size: 12, font });
        page.drawText('Total', { x: 450, y: yPosition, size: 12, font });
        yPosition -= 20;

        // Table rows
        let totalAmount = 0;
        for (const item of quote.items) {
            const itemTotal = item.quantity * item.price;
            totalAmount += itemTotal;

            page.drawText(item.description, { x: 50, y: yPosition, size: 10, font });
            page.drawText(item.quantity.toString(), { x: 300, y: yPosition, size: 10, font });
            page.drawText(`$${item.price.toFixed(2)}`, { x: 350, y: yPosition, size: 10, font });
            page.drawText(`$${itemTotal.toFixed(2)}`, { x: 450, y: yPosition, size: 10, font });

            yPosition -= 15;
        }

        // Draw total
        yPosition -= 20;
        page.drawLine({
            start: { x: 50, y: yPosition },
            end: { x: 545, y: yPosition },
            thickness: 1,
            color: rgb(0, 0, 0),
        });
        yPosition -= 20;

        page.drawText('TOTAL:', { x: 350, y: yPosition, size: 14, font });
        page.drawText(`$${totalAmount.toFixed(2)}`, { x: 450, y: yPosition, size: 14, font });

        // Save the PDF to a temporary file
        const pdfBytes = await pdfDoc.save();
        const tempPath = path.join(os.tmpdir(), `${docId}-${Date.now()}.pdf`);
        fs.writeFileSync(tempPath, pdfBytes);

        // Upload to Firebase Storage
        const bucket = storage.bucket();
        const storagePath = `orgs/${orgId}/quotes/${docId}.pdf`;
        await bucket.upload(tempPath, {
            destination: storagePath,
            metadata: {
                contentType: 'application/pdf',
                cacheControl: 'public, max-age=31536000',
            },
        });

        // Generate signed URL
        const [signedUrl] = await bucket.file(storagePath).getSignedUrl({
            action: 'read',
            expires: '03-09-2491', // Far future date
        });

        // Update Firestore with PDF URL
        await quoteRef.update({
            pdfUrl: signedUrl,
            pdfGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Clean up temp file
        fs.unlinkSync(tempPath);

        return {
            success: true,
            pdfUrl: signedUrl,
            quoteId: docId
        };


    } catch (error) {
        functions.logger.error('PDF generation failed:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Failed to generate PDF',
            error instanceof Error ? error.message : String(error)
        );
    }
});