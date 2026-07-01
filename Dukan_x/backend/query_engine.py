"""
QueryEngine: Text-to-SQL for Business Queries
Translates natural language questions into SQL, executes, and formats results.
"""

import logging
import json
import sqlite3
import os
from pathlib import Path
from typing import Dict, Any, List, Optional
from groq import AsyncGroq
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("QueryEngine")

class QueryEngine:
    def __init__(self, db_path: Optional[str] = None):
        self.api_key = os.getenv("GROQ_API_KEY")
        self.client = AsyncGroq(api_key=self.api_key)
        self.model = "llama-3.1-8b-instant"
        
        # Database path - set via environment or auto-detect
        self.db_path = db_path or os.getenv("DUKANX_DB_PATH") or self._find_db()
        logger.info(f"📂 Database Path: {self.db_path or 'NOT FOUND (using mock)'}")
        
        # Accurate schema from DukanX Drift tables
        self.SCHEMA_PROMPT = """
You are a SQL expert for DukanX, a business management app.
Convert natural language questions to SQLite queries.

DATABASE SCHEMA (DRIFT/SQLite):
--------------------------------

-- bills (Sales Invoices)
CREATE TABLE bills (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    invoice_number TEXT,
    customer_id TEXT,
    customer_name TEXT,
    bill_date INTEGER NOT NULL,  -- Unix timestamp (seconds since epoch)
    subtotal REAL DEFAULT 0.0,
    tax_amount REAL DEFAULT 0.0,
    discount_amount REAL DEFAULT 0.0,
    grand_total REAL DEFAULT 0.0,
    paid_amount REAL DEFAULT 0.0,
    status TEXT DEFAULT 'DRAFT',  -- DRAFT, PENDING, PARTIAL, PAID, CANCELLED
    payment_mode TEXT,
    cash_paid REAL DEFAULT 0.0,
    online_paid REAL DEFAULT 0.0,
    business_type TEXT DEFAULT 'generalStore',
    created_at INTEGER,
    updated_at INTEGER,
    deleted_at INTEGER  -- NULL if not deleted
);

-- customers
CREATE TABLE customers (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    gstin TEXT,
    total_billed REAL DEFAULT 0.0,
    total_paid REAL DEFAULT 0.0,
    total_dues REAL DEFAULT 0.0,
    is_active INTEGER DEFAULT 1,
    created_at INTEGER,
    deleted_at INTEGER
);

-- products
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sku TEXT,
    barcode TEXT,
    category TEXT,
    unit TEXT DEFAULT 'pcs',
    selling_price REAL NOT NULL,
    cost_price REAL DEFAULT 0.0,
    stock_quantity REAL DEFAULT 0.0,
    low_stock_threshold REAL DEFAULT 10.0,
    is_active INTEGER DEFAULT 1,
    hsn_code TEXT,
    created_at INTEGER,
    deleted_at INTEGER
);

-- journal_entries (Accounting)
CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    voucher_number TEXT,
    voucher_type TEXT,  -- SALES, PURCHASE, RECEIPT, PAYMENT
    entry_date INTEGER,
    narration TEXT,
    total_debit REAL,
    total_credit REAL,
    created_at INTEGER
);

RULES:
------
1. Output ONLY valid JSON: {"sql": "...", "explanation": "..."}
2. Timestamps are Unix epoch (INTEGER). Use datetime() function:
   - Today: datetime(bill_date, 'unixepoch') >= datetime('now', 'start of day')
   - This month: strftime('%Y-%m', datetime(bill_date, 'unixepoch')) = strftime('%Y-%m', 'now')
   - This week: bill_date >= strftime('%s', 'now', '-7 days')
3. ALWAYS filter: user_id = '{user_uid}' AND deleted_at IS NULL
4. Limit to 20 rows max.
5. Return null sql if question is unanswerable.

EXAMPLES:
---------
User: "आज की sale कितनी हुई?"
Output: {{"sql": "SELECT COALESCE(SUM(grand_total), 0) as total_sales FROM bills WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND datetime(bill_date, 'unixepoch') >= datetime('now', 'start of day')", "explanation": "Today's total sales"}}

User: "Top 5 customers with dues"
Output: {{"sql": "SELECT name, total_dues FROM customers WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND total_dues > 0 ORDER BY total_dues DESC LIMIT 5", "explanation": "Top 5 customers by pending dues"}}

User: "Stock of milk"
Output: {{"sql": "SELECT name, stock_quantity, unit FROM products WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND LOWER(name) LIKE '%milk%'", "explanation": "Stock for products matching 'milk'"}}

User: "This month revenue"
Output: {{"sql": "SELECT COALESCE(SUM(grand_total), 0) as revenue FROM bills WHERE user_id = '{user_uid}' AND deleted_at IS NULL AND strftime('%Y-%m', datetime(bill_date, 'unixepoch')) = strftime('%Y-%m', 'now')", "explanation": "Total revenue this month"}}
"""

    def _find_db(self) -> Optional[str]:
        """Try to find the app's database file in common locations."""
        import platform
        
        home = Path.home()
        possible_paths = []
        
        # Windows paths
        if platform.system() == "Windows":
            possible_paths = [
                # Flutter Windows app data
                home / "AppData/Roaming/com.example.dukan_x/dukan_x.db",
                home / "AppData/Local/com.example.dukan_x/dukan_x.db",
                # Direct project path for development
                Path("../test_database.db"),
                Path("test_database.db"),
                # Android Emulator via ADB pull (developer may copy here)
                Path("./dukan_x.db"),
            ]
        # Linux / macOS
        else:
            possible_paths = [
                home / ".local/share/com.example.dukan_x/dukan_x.db",
                Path("./dukan_x.db"),
                Path("test_database.db"),
            ]
        
        for p in possible_paths:
            if p.exists():
                logger.info(f"✅ Found database at: {p}")
                return str(p.resolve())
        
        logger.warning("⚠️ No database file found. Will use mock data.")
        return None

    async def run_query(self, user_uid: str, question: str) -> Dict[str, Any]:
        """
        Main entry point.
        1. Translate question to SQL using LLM.
        2. Execute SQL against local database.
        3. Format and return results.
        """
        logger.info(f"📊 Query Request: {question} (User: {user_uid})")
        
        # 1. Generate SQL
        sql_result = await self._generate_sql(user_uid, question)
        
        if not sql_result.get("sql"):
            return {
                "success": False,
                "text": sql_result.get("explanation", "I couldn't understand that question for the database."),
                "data": None
            }
        
        sql = sql_result["sql"]
        explanation = sql_result.get("explanation", "")
        
        # 2. Execute SQL
        try:
            results = self._execute_sql(sql)
        except Exception as e:
            logger.error(f"SQL Execution Error: {e}")
            return {
                "success": False,
                "text": f"Query failed: {str(e)}",
                "data": None,
                "sql": sql
            }
        
        # 3. Format Response
        formatted = self._format_results(results, explanation, question)
        
        return {
            "success": True,
            "text": formatted["text"],
            "data": {
                "rows": results,
                "count": len(results),
                "sql": sql
            }
        }

    async def _generate_sql(self, user_uid: str, question: str) -> Dict[str, Any]:
        """Use LLM to convert question to SQL."""
        prompt = self.SCHEMA_PROMPT.replace("{user_uid}", user_uid)
        
        try:
            completion = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": question}
                ],
                temperature=0.0,
                max_tokens=512,
                response_format={"type": "json_object"}
            )
            
            content = completion.choices[0].message.content
            parsed = json.loads(content)
            
            return {
                "sql": parsed.get("sql"),
                "explanation": parsed.get("explanation", "")
            }
            
        except Exception as e:
            logger.error(f"SQL Generation Error: {e}")
            return {"sql": None, "explanation": f"LLM Error: {str(e)}"}

    def _execute_sql(self, sql: str) -> List[Dict[str, Any]]:
        """Execute SQL and return results as list of dicts."""
        if not self.db_path:
            # Return mock data for testing when no DB is available
            logger.warning("No database found. Returning mock data.")
            return self._get_mock_data(sql)
        
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        try:
            cursor.execute(sql)
            rows = cursor.fetchall()
            return [dict(row) for row in rows]
        finally:
            conn.close()

    def _get_mock_data(self, sql: str) -> List[Dict[str, Any]]:
        """Return mock data for testing without a real database."""
        sql_lower = sql.lower()
        
        if "sum(grand_total)" in sql_lower:
            return [{"total_sales": 15750.00}]
        elif "customers" in sql_lower and "total_dues" in sql_lower:
            return [
                {"name": "Raju Enterprises", "total_dues": 5200.00},
                {"name": "Sharma Traders", "total_dues": 3100.00},
                {"name": "Gupta Electronics", "total_dues": 2800.00},
            ]
        elif "products" in sql_lower and "stock" in sql_lower:
            return [{"name": "Amul Milk 500ml", "stock_quantity": 42, "unit": "packet"}]
        else:
            return [{"message": "Mock data - no database connected"}]

    def _format_results(self, results: List[Dict], explanation: str, question: str) -> Dict[str, str]:
        """Format query results into natural language."""
        if not results:
            return {"text": "No data found for your query."}
        
        # Single aggregation result
        if len(results) == 1:
            row = results[0]
            if "total_sales" in row:
                val = row["total_sales"] or 0
                return {"text": f"Today's total sales: ₹{val:,.2f}"}
            elif "total_dues" in row:
                return {"text": f"Pending dues: ₹{row['total_dues']:,.2f}"}
            elif "stock_quantity" in row:
                return {"text": f"{row.get('name', 'Product')}: {row['stock_quantity']} {row.get('unit', 'units')} in stock."}
        
        # List results
        if len(results) > 1:
            # Format as a simple list
            lines = [explanation + ":"] if explanation else []
            for i, row in enumerate(results[:10], 1):
                # Dynamically format based on keys
                if "name" in row and "total_dues" in row:
                    lines.append(f"{i}. {row['name']}: ₹{row['total_dues']:,.2f}")
                elif "name" in row and "grand_total" in row:
                    lines.append(f"{i}. {row['name']}: ₹{row['grand_total']:,.2f}")
                elif "customer_name" in row:
                    lines.append(f"{i}. {row['customer_name']}")
                else:
                    # Generic formatting
                    parts = [f"{k}: {v}" for k, v in row.items() if v is not None]
                    lines.append(f"{i}. " + ", ".join(parts[:3]))
            
            if len(results) > 10:
                lines.append(f"... and {len(results) - 10} more.")
            
            return {"text": "\n".join(lines)}
        
        # Fallback
        return {"text": f"Found {len(results)} results. {explanation}"}


# Singleton instance
query_engine = QueryEngine()
