import { S3 } from 'aws-sdk';
import crypto from 'crypto';
import { fileTypeFromBuffer } from 'file-type';
import { loadFromEnv } from './utils';

export async function upload(event) {
    const s3 = new S3();
    const shasum = crypto.createHash('sha1');

    const { body: { base64String } } = event;
    const buffer = Buffer.from(base64String, 'base64');
    const info: any = await fileTypeFromBuffer(buffer);

    // get the hash for the filename
    shasum.update(String(new Date()));
    const hash = shasum.digest();
    const filepath = hash + '/';
    const filename = crypto.randomUUID() + '.' + info.ext;
    const fullpath = filepath + filename;

    const params = {
        Bucket: null, // todo: pull bucket name from event path
        Key: fullpath,
        Body: buffer,
        ContentType: info.mime,
    };

    // todo: await s3.putObject()

    return {
        size: buffer.toString('ascii').length,
        type: info.mime,
        filename,
        fullpath,
    };
}
