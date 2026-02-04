"""
Taishin Bank (台新銀行) credit card statement parser.
"""
import re
from datetime import date
from decimal import Decimal
from typing import Optional

from .base import BaseParser, ParsedBill


class TaishinParser(BaseParser):
    """Parser for Taishin Bank (台新銀行) credit card statements."""
    
    BANK_NAME = "Taishin Bank"
    BANK_CODE = "TSB"
    
    # Detection keywords
    DETECTION_KEYWORDS = ["台新", "Taishin", "TSBank", "Richart", "台新銀行"]
    
    # Amount extraction patterns
    AMOUNT_PATTERNS = {
        "total_amount": [
            r'本期應繳總金額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'本期應繳金額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'應繳總額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'繳款總額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'本期總應繳金額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
        ],
        "minimum_due": [
            r'最低應繳金額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'最低應繳款[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
            r'最低繳款額[\s:]*[NT$]*\s*([\d,]+\.?\d*)',
        ]
    }
    
    # Date extraction patterns
    DATE_PATTERNS = {
        "statement_date": [
            r'結帳日[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'帳單日期[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'結帳日期[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})\s*結帳',
            r'帳單結算日[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
        ],
        "due_date": [
            r'繳款截止日[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'最後繳款日[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'繳款期限[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'繳款截止期限[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'最後繳款期限[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
        ]
    }
    
    # Card number patterns
    CARD_PATTERNS = [
        r'卡號末四碼[\s:]*(\d{4})',
        r'信用卡末四碼[\s:]*(\d{4})',
        r'卡號.*[-\s](\d{4})',
        r'\*{4}[-\s]*(\d{4})',
        r'尾號[\s:]*(\d{4})',
        r'卡片末四碼[\s:]*(\d{4})',
    ]
    
    def can_parse(self, text: str) -> bool:
        """Check if text is a Taishin Bank statement."""
        text_lower = text.lower()
        return any(
            keyword.lower() in text_lower 
            for keyword in self.DETECTION_KEYWORDS
        )
    
    def parse(self, text: str) -> ParsedBill:
        """Parse Taishin Bank statement."""
        text = self.clean_text(text)
        
        # Extract card last four
        card_last_four = self.extract_card_last_four(text, self.CARD_PATTERNS) or "0000"
        
        # Extract dates
        statement_date = self.extract_date(text, self.DATE_PATTERNS["statement_date"])
        due_date = self.extract_date(text, self.DATE_PATTERNS["due_date"])
        
        # Default dates if not found
        if not statement_date:
            from datetime import datetime
            statement_date = datetime.now().date()
        
        if not due_date:
            # Due date is typically 20 days after statement for Taishin
            from datetime import timedelta
            due_date = statement_date + timedelta(days=20)
        
        # Extract amounts
        total_amount = self.extract_amount(text, self.AMOUNT_PATTERNS["total_amount"])
        minimum_due = self.extract_amount(text, self.AMOUNT_PATTERNS["minimum_due"])
        
        # Default amounts if not found
        if not total_amount:
            total_amount = Decimal("0")
        
        # Calculate statement month
        statement_month = statement_date.strftime("%Y-%m")
        
        # Build result
        bill = ParsedBill(
            bank_name=self.BANK_NAME,
            card_last_four=card_last_four,
            statement_date=statement_date,
            statement_month=statement_month,
            due_date=due_date,
            total_amount_due=total_amount,
            minimum_due=minimum_due,
            currency="TWD",
            raw_text=text[:1000]
        )
        
        # Calculate confidence
        bill.confidence_score = self.calculate_confidence(bill)
        
        # Track extracted fields
        bill.extracted_fields = []
        if card_last_four != "0000":
            bill.extracted_fields.append("card_last_four")
        if statement_date:
            bill.extracted_fields.append("statement_date")
        if due_date:
            bill.extracted_fields.append("due_date")
        if total_amount and total_amount > 0:
            bill.extracted_fields.append("total_amount_due")
        if minimum_due:
            bill.extracted_fields.append("minimum_due")
        
        return bill
    
    def calculate_confidence(self, parsed_bill: ParsedBill) -> float:
        """Calculate confidence score for Taishin parsing."""
        score = 0.0
        
        # Bank name
        score += 0.1
        
        # Card last four
        if parsed_bill.card_last_four and parsed_bill.card_last_four != "0000":
            score += 0.1
        
        # Statement date
        if parsed_bill.statement_date:
            score += 0.15
        
        # Due date
        if parsed_bill.due_date:
            score += 0.2
        
        # Total amount - critical field
        if parsed_bill.total_amount_due and parsed_bill.total_amount_due > 0:
            score += 0.3
        else:
            score -= 0.2
        
        # Minimum due
        if parsed_bill.minimum_due:
            score += 0.15
        
        return max(0.0, min(1.0, round(score, 2)))
