import { upload } from './s3-handler';
import { queueImageForIngest } from './sqs-handler';
import * as multipart from 'parse-multipart-data';

export const handler = async (event: any, context: any) => {
    const response = {
        headers: { 'content-type': 'application/json' },
        statusCode: 200,
        body: {},
    };

    try {
        // first, upload
        const inputs = parseMultipartPayload(event);
        const bucket = event.pathParameters.folder;
        
        if (inputs.files.length !== 1) throw new Error('exactly one file upload must be provided');

        const image = await upload(bucket, inputs.files[0]);

        // now, we queue up the ingestion details
        const data = await queueImageForIngest({
            meta: { bucket },
            image
        });

        response.body = {
            id: data.MessageId,
            image,
        };
    } catch (err: any) {
        response.statusCode = 402;
        response.body = { error: err.message };
    }

    response.body = JSON.stringify(response.body);
    return response;
}

function parseMultipartPayload(event: any) {
    const { headers } = event;
    const contentType = headers['Content-Type'];
    const boundary = (contentType.match(/.*boundary=(.*)$/))[1];
    const parts = multipart.parse(Buffer.from(event.body, 'base64'), boundary);
    const fields = parts.reduce((prev: any, curr: any) => {
        if (curr.hasOwnProperty('filename')) prev.files.push(curr);
        else prev[curr.name] = String(curr.data);

        return prev;
    }, { files: [] });

    return fields;
}