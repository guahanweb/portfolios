import path from 'path';
import fs from 'fs';
import dotenv from 'dotenv';
import { ILogLevel } from './logger';

const env: string = loadEnvironment();
const configuration = loadConfiguration(env);

export default configuration;

function loadConfiguration(env: string) {
    return {
        environment: env,
        host: loadFromEnv('HOST', 'localhost') as string,
        port: loadFromEnv('PORT', 3000) as string,
        service: loadFromEnv('SERVICE_NAME', 'portfolio-sandbox') as string,
        logLevel: loadFromEnv('LOG_LEVEL', 'debug') as ILogLevel,
        imagePath: loadImagePath(),
    };
}

function loadImagePath() {
    const imagePath = path.resolve(process.cwd(), loadFromEnv('IMAGE_PATH', 'images') as string);

    return imagePath;
}

function loadEnvironment() {
    let filename = loadFromEnv('ENV_FILE') as undefined|string;
    let env = loadFromEnv('NODE_ENV', 'development') as string;

    if (typeof filename !== 'undefined') {
        const envFilePath = path.resolve(process.cwd(), filename);

        if (!fs.existsSync(envFilePath)) {
            console.error('environmentfile does not exist:', envFilePath);
            process.exit(1);
        }

        dotenv.config({ path: envFilePath });
    } else {
        const supportedFiles = [
            `.${env}.env`,
            '.env'
        ].map(file => path.resolve(__dirname, `./${file}`));

        let loaded = false;

        supportedFiles.forEach((file: string) => {
            if (!loaded && fs.existsSync(file)) {
                dotenv.config({ path: file });
                loaded = true;
            }
        });
    }

    return env;
}

function loadFromEnv(key: string, defaultValue?: string|number|boolean) {
    const value = process.env && process.env[key];

    return value || defaultValue;
}
