import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { loadFromEnv } from './utils';
import crypto from 'crypto';
import path from 'path';

interface IFile {
    filename: string;
    type: string;
    name: string;
    data: Buffer;
}

const region = loadFromEnv('AWS_REGION', 'us-east-1');
const endpoint = loadFromEnv('AWS_ENDPOINT_URL', undefined);

export async function upload(bucket: string, file: IFile) {
    const props: any = { region, endpoint };
    if (props.endpoint) props.forcePathStyle = true;
    const s3 = new S3Client(props);
    const shasum = crypto.createHash('sha1');
    const { filename, type, data } = file
    const ext = path.extname(filename);

    // get the hash for the filename
    shasum.update(String(new Date()));
    const hash = shasum.digest('hex');
    const filepath = hash + '/';
    const fullpath = filepath + crypto.randomUUID() + ext;

    const params = {
        Bucket: bucket,
        Key: fullpath,
        Body: data,
        ContentType: type,
    };

    const result = await s3.send(new PutObjectCommand(params));

    return {
        size: data.toString('ascii').length,
        type,
        filename,
        fullpath,
    };
}
