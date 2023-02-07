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
                DataType: "String",
                StringValue: action,
            },
            Filename: {
                DataType: "String",
                StringValue: request.image.filename,
            },
            Filetype: {
                DataType: "String",
                StringValue: request.image.type,
            },
            ObjectPath: {
                DataType: "String",
                StringValue: request.image.fullpath,
            },
            S3Bucket: {
                DataType: "String",
                StringValue: request.meta.bucket,
            }
        },
        MessageBody: `${action} requested for s3://${request.meta.bucket}/${request.image.fullpath}`,
        QueueUrl: queueUrl,
    };

    const data = await sqs.send(new SendMessageCommand(params));
    return data;
}
