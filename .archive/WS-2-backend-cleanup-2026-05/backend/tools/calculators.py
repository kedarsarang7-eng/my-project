def calculate_period_stats(bills: list):
    """
    Calculates total revenue, bill count, average bill value.
    """
    if not bills:
        return {
            "total_revenue": 0,
            "bill_count": 0,
            "avg_bill_value": 0,
            "top_items": []
        }

    total_revenue = sum(float(b.get('grandTotal', 0)) for b in bills)
    bill_count = len(bills)
    
    # Item analysis
    item_counts = {}
    for b in bills:
        items = b.get('items', [])
        for item in items:
            name = item.get('vegName') or item.get('itemName') or "Unknown"
            qty = float(item.get('qty', 0))
            item_counts[name] = item_counts.get(name, 0) + qty

    # Sort top items
    sorted_items = sorted(item_counts.items(), key=lambda x: x[1], reverse=True)[:5]
    top_items = [{"name": k, "qty": v} for k, v in sorted_items]
    total_units = sum(item_counts.values())

    return {
        "total_revenue": total_revenue,
        "bill_count": bill_count,
        "avg_bill_value": total_revenue / bill_count if bill_count else 0,
        "top_items": top_items,
        "total_units_sold": total_units
    }

def safe_float(val):
    try:
        return float(val)
    except:
        return 0.0

def calculate_cash_flow(sales_total: float, purchase_total: float):
    net = sales_total - purchase_total
    status = "Profit" if net >= 0 else "Loss"
    return {
        "total_sales": sales_total,
        "total_purchases": purchase_total,
        "net_value": net,
        "status": status
    }
