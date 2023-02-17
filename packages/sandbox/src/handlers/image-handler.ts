import { Request, Response } from 'express';
import sharp from 'sharp';
import fs from 'fs';

export function serveImage({ imagePath }: any) {
    return async function (req: Request, res: Response) {
        const { filename } = req.params;
        const filepath = `${imagePath}/${filename}`;

        if (!fs.existsSync(filepath)) {
            return res.status(404).send('not found');
        }

        const widthString = req.query.width;
        const heightString = req.query.height;
        const format = req.query.format;

        let width, height;
        if (widthString) width = parseInt(widthString as string);
        if (heightString) height = parseInt(heightString as string);
        
        res.type(`image/${format || 'png'}`);
        resize(filepath, { height, width, format }).pipe(res);
    }
}

export function serveThumbnail({ imagePath }: any) {
    return async function (req: Request, res: Response) {
        const { filename } = req.params;
        const filepath = `${imagePath}/${filename}`;

        if (!fs.existsSync(filepath)) {
            return res.status(404).send('not found');
        }

        const format = req.query.format;
        const width = 200;
        const height = 200;
        
        res.type(`image/${format || 'png'}`);
        resize(filepath, {
            height,
            width,
            format,
            resizeOpts: {
                fit: sharp.fit.cover,
                position: sharp.strategy.entropy,
            }
        }).pipe(res);
    }
}

function resize(filepath: string, { height, width, format, resizeOpts = {} }: any) {
    const readStream = fs.createReadStream(filepath);

    let transform = sharp();

    if (format) {
        transform = transform.toFormat(format);
    }
    
    if (width || height) {
        const opts = { width, height, ...resizeOpts };
        transform = transform.resize(opts);
    }

    return readStream.pipe(transform);
}
