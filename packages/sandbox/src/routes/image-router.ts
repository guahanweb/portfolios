import { Router } from 'express';
import { serveImage, serveThumbnail } from '../handlers/image-handler';

export function initialize({ imagePath }: any) {
    const router = Router();

    router.get('/:filename', serveImage({ imagePath }));
    router.get('/:filename/thumb', serveThumbnail({ imagePath }))

    return router;
}