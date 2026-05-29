// Dashboard Service - Type Definitions
// This file provides type definitions for dashboard sections used by business strategies

export interface DashboardSection {
    id: string;
    title: string;
    type: 'chart' | 'table' | 'metric' | 'list' | 'alert';
    data?: any;
    config?: Record<string, unknown>;
}
