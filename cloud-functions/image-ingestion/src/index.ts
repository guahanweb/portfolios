export const handler = async (event: any, context: any) => {
    event.Records.forEach((record: any) => {
        const { body, messageAttributes } = record;
        const attributes = parseMessageAttributes(messageAttributes);

        console.log(attributes);
    });

    return {};
};

interface IMessageAttributes {
    [key: string]: {
        dataType: "String"|"Number"|"Binary";
        stringValue?: string;
        numberValue?: string;
    }
}

function parseMessageAttributes(attributes: IMessageAttributes) {
    return Object.keys(attributes).reduce<any>((prev: any, curr: string) => {
        const value = attributes[curr];
        const key = curr.toLowerCase();

        switch (value.dataType) {
            case 'String':
                prev[key] = value.stringValue;
                break;

            case 'Number':
                prev[key] = (value.numberValue?.indexOf('.') === -1)
                    ? parseInt(value.numberValue)
                    : parseFloat(value.numberValue as string);
                break;

            default:
                // skip, since we don't support the type
        }
    }, {});
}
