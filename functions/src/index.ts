import { onCall } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as nodemailer from "nodemailer";
import { google } from "googleapis";

interface JoinRequestData {
    orgName: string;
    userEmail: string;
    adminEmail: string;
}

// OAuth2 client setup
const oauth2Client = new google.auth.OAuth2(
    process.env.GMAIL_CLIENT_ID,
    process.env.GMAIL_CLIENT_SECRET,
    process.env.GMAIL_REDIRECT_URI
);

oauth2Client.setCredentials({
    refresh_token: process.env.GMAIL_REFRESH_TOKEN
});
export const sendJoinRequest = onCall<JoinRequestData>(
    {
        secrets: [
            "GMAIL_CLIENT_ID",
            "GMAIL_CLIENT_SECRET",
            "GMAIL_REDIRECT_URI",
            "GMAIL_REFRESH_TOKEN",
            "GMAIL_USER"
        ]
    },
    async (request) => {
        const { orgName, userEmail, adminEmail } = request.data;

        if (!orgName || !userEmail || !adminEmail) {
            throw new HttpsError("invalid-argument", "Missing parameters");
        }

        try {
            // Get new access token
            const { token } = await oauth2Client.getAccessToken();

            if (!token) {
                throw new HttpsError("internal", "Failed to get access token");
            }

            // Create transporter with OAuth2
            const transporter = nodemailer.createTransport({
                service: "gmail",
                auth: {
                    type: "OAuth2",
                    user: process.env.GMAIL_USER,
                    clientId: process.env.GMAIL_CLIENT_ID,
                    clientSecret: process.env.GMAIL_CLIENT_SECRET,
                    refreshToken: process.env.GMAIL_REFRESH_TOKEN,
                    accessToken: token,
                },
            });

            const mailOptions = {
                from: `Ventzor <${process.env.GMAIL_USER}>`,
                to: adminEmail,
                subject: `Join Request for "${orgName}"`,
                text: `${userEmail} is requesting to join your organization "${orgName}" on Ventzor.`,
            };

            await transporter.sendMail(mailOptions);
            return { success: true };
        } catch (error) {
            logger.error("Email send error:", error);
            throw new HttpsError("internal", "Failed to send email.");
        }
    }
);