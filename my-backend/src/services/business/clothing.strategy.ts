// ============================================================================
// Clothing Business Strategy — Dashboard Sections (DynamoDB)
// ============================================================================

import { Keys, queryItems } from '../../config/dynamodb.config';
import { DashboardSection } from '../dashboard.service';
import { BaseStrategy } from './base.strategy';

export class ClothingStrategy extends BaseStrategy {
    async getDashboardSections(tenantId: string): Promise<DashboardSection[]> {
        const sections = await super.getDashboardSections(tenantId);

        const [variantSummary, lowStockVariants, sizeMatrix, colorMatrix] = await Promise.all([
            this.getVariantSummary(tenantId),
            this.getLowStockVariants(tenantId),
            this.getSizeMatrix(tenantId),
            this.getColorMatrix(tenantId),
        ]);

        sections.unshift({
            id: 'clothing_variant_summary',
            title: 'Variant Summary',
            type: 'metric',
            data: variantSummary,
        });

        sections.unshift({
            id: 'clothing_low_stock_variants',
            title: 'Low Stock Variants',
            type: 'alert',
            data: lowStockVariants,
        });

        sections.push({
            id: 'clothing_size_matrix',
            title: 'Size-wise Stock Matrix',
            type: 'table',
            data: sizeMatrix,
        });

        sections.push({
            id: 'clothing_color_matrix',
            title: 'Color-wise Stock Matrix',
            type: 'table',
            data: colorMatrix,
        });

        return sections;
    }

    private async getVariantSummary(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :clothing AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':clothing': 'clothing', ':true': true, ':false': false },
        });

        const groups = new Set<string>();
        let withVariants = 0;
        let totalStock = 0;

        for (const product of result.items) {
            const groupId = product.variantGroupId || product.attributes?.groupId || '';
            if (groupId) {
                groups.add(String(groupId));
                withVariants++;
            }
            totalStock += Number(product.currentStock || 0);
        }

        return {
            total_products: result.items.length,
            variant_groups: groups.size,
            variant_items: withVariants,
            total_stock: totalStock,
        };
    }

    private async getLowStockVariants(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :clothing AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false) AND currentStock <= lowStockThreshold',
            expressionAttributeValues: { ':clothing': 'clothing', ':true': true, ':false': false },
            limit: 20,
        });

        return result.items
            .sort((a, b) => (Number(a.currentStock || 0)) - (Number(b.currentStock || 0)))
            .slice(0, 10)
            .map(p => ({
                id: p.id,
                name: p.name,
                size: p.attributes?.size || p.size || '',
                color: p.attributes?.color || p.color || '',
                current_stock: Number(p.currentStock || 0),
                threshold: Number(p.lowStockThreshold || 0),
                variant_group_id: p.variantGroupId || p.attributes?.groupId || null,
            }));
    }

    private async getSizeMatrix(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :clothing AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':clothing': 'clothing', ':true': true, ':false': false },
        });

        const bySize: Record<string, { count: number; stock: number; value: number }> = {};
        for (const p of result.items) {
            const size = String(p.attributes?.size || p.size || 'Unknown');
            if (!bySize[size]) bySize[size] = { count: 0, stock: 0, value: 0 };
            bySize[size].count++;
            bySize[size].stock += Number(p.currentStock || 0);
            bySize[size].value += Number(p.currentStock || 0) * Number(p.salePriceCents || 0);
        }

        return Object.entries(bySize)
            .map(([size, data]) => ({
                size,
                product_count: data.count,
                total_stock: data.stock,
                stock_value_cents: data.value,
            }))
            .sort((a, b) => a.size.localeCompare(b.size));
    }

    private async getColorMatrix(tenantId: string) {
        const result = await queryItems<Record<string, any>>(Keys.tenantPK(tenantId), 'PRODUCT#', {
            filterExpression: 'productType = :clothing AND isActive = :true AND (attribute_not_exists(isDeleted) OR isDeleted = :false)',
            expressionAttributeValues: { ':clothing': 'clothing', ':true': true, ':false': false },
        });

        const byColor: Record<string, { count: number; stock: number; value: number }> = {};
        for (const p of result.items) {
            const color = String(p.attributes?.color || p.color || 'Unknown');
            if (!byColor[color]) byColor[color] = { count: 0, stock: 0, value: 0 };
            byColor[color].count++;
            byColor[color].stock += Number(p.currentStock || 0);
            byColor[color].value += Number(p.currentStock || 0) * Number(p.salePriceCents || 0);
        }

        return Object.entries(byColor)
            .map(([color, data]) => ({
                color,
                product_count: data.count,
                total_stock: data.stock,
                stock_value_cents: data.value,
            }))
            .sort((a, b) => a.color.localeCompare(b.color));
    }
}