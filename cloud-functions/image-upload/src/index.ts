import AWS from 'aws-sdk';
import crypto from 'crypto';
import { fileTypeFromBuffer } from 'file-type';

const s3 = new AWS.S3();

export const handler = async (event: any, context: any) => {
    const request = event.body;
    const base64String = request.base64String;
    const buffer = Buffer.from(base64String, 'base64');
    const info = await fileTypeFromBuffer(buffer);

    const file = getFile(info, buffer);
}

function getFile(mime: any, buffer: Buffer) {
    const shasum = crypto.createHash('sha1');
    const datetime = (new Date()).toString();
    shasum.update(datetime);

    const hash = shasum.digest('hex');
    const fileExt = mime.ext;
    const filePath = hash + '/';
    const filename = crypto.randomUUID() + '.' + fileExt;
    const fullFilepath = filePath + filename;

    let params = {
        Bucket: 'my-bucket',
        Key: fullFilepath,
        Body: buffer,
        ContentType: mime.mime,
    };

    let uploadedFile = {
        size: buffer.toString('ascii').length,
        type: mime.mime,
        name: filename,
        full_path: fullFilepath,
    }

    return {
        params,
        uploadedFile,
    }
}