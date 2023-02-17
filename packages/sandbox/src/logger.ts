import { createLogger, format, transports, Logger } from 'winston';
import { TransformableInfo } from 'logform';

const { combine, splat, timestamp, printf } = format;

export type ILogLevel = "verbose"|"debug"|"info"|"warn"|"error"|"fatal"

let logger: Logger;
export function initialize(log_level: ILogLevel, service_name = "service") {
    if (typeof logger === 'undefined') {
        const addServiceName = format((info: any) => {
            info.service = service_name;

            return info;
        });

        function customFormat() {
            return printf(({ level, message, timestamp, ...metadata }: TransformableInfo) => {
                let msg = `${timestamp} [${level}] : ${message}`;

                if (metadata) {
                    msg += (' ' + JSON.stringify(metadata));
                }

                return msg;
            })
        }

        logger = createLogger({
            level: log_level,
            format: combine(
                format.colorize(),
                splat(),
                timestamp(),
                addServiceName(),
                customFormat(),
            ),
            transports: [
                new transports.Console({ level: log_level }),
            ]
        });
    }

    return logger;
}

export function instance() {
    if (typeof logger === 'undefined') {
        throw new Error('logger not yet initialized');
    }

    return logger;
}
