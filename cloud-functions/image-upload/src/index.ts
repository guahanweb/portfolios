import { upload } from './s3-handler';
import * as multipart from 'parse-multipart-data';

export const handler = async (event: any, context: any) => {
    // first, upload
    const inputs = parseMultipartPayload(event);
    const bucket = event.pathParameters.folder;
    
    let uploads: Promise<any>[] = [];
    inputs.forEach((input: any) => {
        // handle the uploads
        if (input.hasOwnProperty('filename')) {
            uploads.push(upload(bucket, input));
        }
    });

    const results = await Promise.all(uploads);

    // todo: queue item ingestion
    // await sqs.sendMessage()
    return {
        headers: { 'content-type': 'application/json' },
        statusCode: 200,
        body: JSON.stringify({
            results,
        }),
    };
}

function parseMultipartPayload(event: any) {
    const { headers } = event;
    const contentType = headers['Content-Type'];
    const boundary = (contentType.match(/.*boundary=(.*)$/))[1];
    const parts = multipart.parse(Buffer.from(event.body, 'base64'), boundary);

    return parts;
}