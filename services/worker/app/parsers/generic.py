"""
Generic fallback parser for unknown bank statements.
Attempts to extract common fields using generic patterns.
"""
import re
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Optional

from .base import BaseParser, ParsedBill, BankDetector


class GenericParser(BaseParser):
    """
    Generic parser that attempts to extract data from any statement.
    
    Used as a fallback when no specific bank parser matches.
    Has lower confidence scores due to generic pattern matching.
    """
    
    BANK_NAME = "Unknown Bank"
    BANK_CODE = "UNKNOWN"
    
    # Generic patterns that work across many statements
    AMOUNT_PATTERNS = {
        "total_amount": [
            r'(?:應繳|應付|繳款|payment|total|amount).*?(?:金額|amount|total)[\s:]*[NT$NTD]*\s*([\d,]+\.?\d*)',
            r'(?:本期|當期|this|current).*?(?:金額|amount)[\s:]*[NT$NTD]*\s*([\d,]+\.?\d*)',
            r'[$¥€£]\s*([\d,]+\.?\d*)',
            r'([\d,]+\.?\d*)\s*(?:元|圓|TWD|NTD?)',
        ],
        "minimum_due": [
            r'(?:最低|minimum).*?(?:金額|amount|payment)[\s:]*[NT$NTD]*\s*([\d,]+\.?\d*)',
            r'(?:最低|minimum).*?(?:應繳|payment)[\s:]*[NT$NTD]*\s*([\d,]+\.?\d*)',
        ]
    }
    
    DATE_PATTERNS = {
        "statement_date": [
            r'(?:結帳|帳單|statement|billing|cutoff).*?(?:日期|date|日)[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'(\d{4}[/-]\d{1,2}[/-]\d{1,2}).*?(?:結帳|statement)',
            r'(?:帳單月份|billing month)[\s:]*(\d{4}[/-]\d{1,2})',
        ],
        "due_date": [
            r'(?:繳款|付款|payment|due).*?(?:日期|截止|期限|date|deadline)[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'(?:最後繳款日|payment due|due date)[\s:]*(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
            r'(\d{4}[/-]\d{1,2}[/-]\d{1,2}).*?(?:繳款|付款|payment)',
        ]
    }
    
    CARD_PATTERNS = [
        r'(?:卡號|card|信用卡).*?(?:末|尾|last).*?(\d{4})',
        r'(?:末|尾|last)\s*(?:四碼|4碼|四|4|\d)\s*[\s:]*(\d{4})',
        r'\*{4}[-\s]*(\d{4})',
        r'xxxx[-\s]*(\d{4})',
        r'####[-\s]*(\d{4})',
    ]
    
    def can_parse(self, text: str) -> bool:
        """
        Generic parser can always attempt to parse.
        Returns True to act as fallback.
        """
        return True
    
    def parse(self, text: str) -> ParsedBill:
        """Parse statement using generic patterns."""
        text = self.clean_text(text)
        
        # Try to detect bank
        detected_bank = BankDetector.detect_bank(text)
        if detected_bank:
            self.BANK_NAME = detected_bank
        
        # Extract card last four
        card_last_four = self.extract_card_last_four(text, self.CARD_PATTERNS) or "0000"
        
        # Extract dates
        statement_date = self.extract_date(text, self.DATE_PATTERNS["statement_date"])
        due_date = self.extract_date(text, self.DATE_PATTERNS["due_date"])
        
        # Default dates
        if not statement_date:
            statement_date = datetime.now().date()
        
        if not due_date:
            due_date = statement_date + timedelta(days=20)
        
        # Extract amounts
        total_amount = self.extract_amount(text, self.AMOUNT_PATTERNS["total_amount"])
        minimum_due = self.extract_amount(text, self.AMOUNT_PATTERNS["minimum_due"])
        
        if not total_amount:
            total_amount = Decimal("0")
        
        # Calculate statement month
        statement_month = statement_date.strftime("%Y-%m")
        
        # Build result with lower confidence
        bill = ParsedBill(
            bank_name=self.BANK_NAME,
            card_last_four=card_last_four,
            statement_date=statement_date,
            statement_month=statement_month,
            due_date=due_date,
            total_amount_due=total_amount,
            minimum_due=minimum_due,
            currency="TWD",
            raw_text=text[:500]  # Store less for generic parser
        )
        
        # Calculate confidence (capped lower for generic parser)
        bill.confidence_score = min(0.6, self.calculate_confidence(bill))
        
        # Mark as requiring review due to generic parsing
        if bill.confidence_score < 0.5:
            bill.extracted_fields = ["needs_review"]
        
        return bill
    
    def calculate_confidence(self, parsed_bill: ParsedBill) -> float:
        """
        Calculate confidence with lower maximum for generic parser.
        """
        score = 0.0
        
        # Bank detection
        if parsed_bill.bank_name != "Unknown Bank":
            score += 0.05
        
        # Card last four
        if parsed_bill.card_last_four and parsed_bill.card_last_four != "0000":
            score += 0.05
        
        # Statement date
        if parsed_bill.statement_date:
            score += 0.1
        
        # Due date
        if parsed_bill.due_date:
            score += 0.15
        
        # Total amount
        if parsed_bill.total_amount_due and parsed_bill.total_amount_due > 0:
            score += 0.25
        
        # Minimum due
        if parsed_bill.minimum_due:
            score += 0.1
        
        # Generic parser penalty - max 60% confidence
        return min(0.6, round(score, 2))
