export function loadFromEnv(variable: string, defaultValue: any) {
    const value = process.env && process.env[variable];

    return value || defaultValue;
}
