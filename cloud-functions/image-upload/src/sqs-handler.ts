import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';
import { loadFromEnv } from './utils';

const region = loadFromEnv('AWS_REGION', 'us-east-1');
const endpoint = loadFromEnv('AWS_ENDPOINT_URL', undefined);
const queueUrl = loadFromEnv('INGEST_QUEUE_URL', undefined);

interface IQueueImageRequest {
    meta: any;
    image: {
        size: number;
        type: string;
        filename: string;
        fullpath: string;
    };
}

export async function queueImageForIngest(request: IQueueImageRequest) {
    const action = "IMAGE.INGEST";
    const sqs = new SQSClient({ region, endpoint });
    const params = {
        DelaySeconds: 0,
        MessageAttributes: {
            Action: {
                StringValue: action,
                DataType: 'String',
            },
            Filename: {
                StringValue: request.image.filename,
                DataType: 'String',
            },
            Filetype: {
                StringValue: request.image.type,
                DataType: 'String',
            },
            Object: {
                StringValue: request.image.fullpath,
                DataType: 'String',
            },
            S3Bucket: {
                StringValue: request.meta.bucket,
                DataType: 'String',
            },
        },
        MessageBody: `${action} requested for s3://${request.meta.bucket}/${request.image.fullpath}`,
        QueueUrl: queueUrl,
    };

    const data = await sqs.send(new SendMessageCommand(params));
    return data;
}
