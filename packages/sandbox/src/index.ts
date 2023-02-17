import { initialize as initializeLogger } from './logger';
import config from './config';
import { createServer } from './server';

main();

async function main() {
    const logger = initializeLogger(config.logLevel, config.service);
    logger.info('logger initialized');

    try {
        const app = createServer(config);

        await app.listen(config.port);
        logger.info('server is listening', { config: { ...config } });
    } catch (err: any) {
        logger.error(err.message, { error: err });
    }
}
