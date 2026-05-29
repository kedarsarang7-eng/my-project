import { Request, Response } from 'express';
import { AutonomousAgentService } from '../services/autonomous-agent.service';
import { logger } from '../utils/logger';

/**
 * Handle AWS EventBridge Hourly Cron Trigger
 */
export const hourlyTrigger = async (req: Request, res: Response): Promise<void> => {
    try {
        logger.info('[Auto Handler] Received Hourly Cron Trigger');

        // Execute background tasks asynchronously so we don't block the Lambda response
        AutonomousAgentService.runHourlyTasks().catch(err => {
            logger.error('[Auto Handler] Async hourly task failed:', err);
        });

        res.status(200).json({ status: 'Hourly tasks queued' });
    } catch (error: any) {
        logger.error('[Auto Handler] Hourly Trigger Error:', error);
        res.status(500).json({ error: 'Internal Scheduler Error' });
    }
};

/**
 * Handle AWS EventBridge Daily (EOD) Cron Trigger
 */
export const dailyTrigger = async (req: Request, res: Response): Promise<void> => {
    try {
        logger.info('[Auto Handler] Received Daily Cron Trigger');

        // Execute background tasks asynchronously
        AutonomousAgentService.runDailyTasks().catch(err => {
            logger.error('[Auto Handler] Async daily task failed:', err);
        });

        // Execute Self-Learning AI memory generation pipeline
        const { AiLearningService } = require('../services/ai-learning.service');
        AiLearningService.runNightlyPipeline().catch((err: any) => {
            logger.error('[AILearning] Nightly pipeline failed:', err);
        });

        res.status(200).json({ status: 'Daily tasks queued' });
    } catch (error: any) {
        logger.error('[Auto Handler] Daily Trigger Error:', error);
        res.status(500).json({ error: 'Internal Scheduler Error' });
    }
};

/**
 * Handle AWS EventBridge Weekly Cron Trigger (For Strategy Agent)
 */
export const weeklyTrigger = async (req: Request, res: Response): Promise<void> => {
    try {
        logger.info('[Auto Handler] Received Weekly Cron Trigger');

        // We could run AIStrategyAgent here directly or trigger Orchestrator with a special prompt
        res.status(200).json({ status: 'Weekly tasks queued' });
    } catch (error: any) {
        logger.error('[Auto Handler] Weekly Trigger Error:', error);
        res.status(500).json({ error: 'Internal Scheduler Error' });
    }
};
