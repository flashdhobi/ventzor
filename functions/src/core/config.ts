// config.ts example
export const PDF_CONFIG = {
    templatePath: process.env.PDF_TEMPLATE_PATH || 'templates/default.html',
    storageBucket: process.env.STORAGE_BUCKET || 'default-bucket'
};