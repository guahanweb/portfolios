export const handler = async (event: any, context: any) => {
    event.Records.forEach((record: any) => {
        const { body } = record;
        console.log(body);
    });

    return {};
};