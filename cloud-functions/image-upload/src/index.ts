import { upload } from './s3-handler';

export const handler = async (event: any, context: any) => {
    // first, upload
    await upload(event);

    // todo: queue item ingestion
    // await sqs.sendMessage()
}