// ============================================
// Logger — Winston Configuration
// ============================================

import winston from 'winston';

const logLevel = process.env.NODE_ENV === 'production' ? 'info' : 'debug';

export const logger = winston.createLogger({
    level: logLevel,
    format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'app-backend' },
    transports: [
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.printf(({ timestamp, level, message, ...meta }) => {
                    const metaStr = Object.keys(meta).length > 1
                        ? ` ${JSON.stringify(meta, null, 0)}`
                        : '';
                    return `${timestamp} [${level}]: ${message}${metaStr}`;
                })
            ),
        }),
        // Production: write to files
        ...(process.env.NODE_ENV === 'production'
            ? [
                new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
                new winston.transports.File({ filename: 'logs/combined.log' }),
            ]
            : []),
    ],
});
