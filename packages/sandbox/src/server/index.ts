import { default as express, Express, Request, Response } from 'express';
import { instance as loggerInstance } from '../logger';
import { initialize as imageRouter } from '../routes/image-router';

export function createServer(config: any): Express {
    const logger = loggerInstance();

    logger.debug('creating server');

    const app = express();

    app.get('/healthcheck', (req: Request, res: Response) => res.send('ok'));
    app.use('/images', imageRouter({ imagePath: config.imagePath }));

    return app;
}