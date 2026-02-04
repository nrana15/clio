"""
Base parser class and utilities for bank statement parsing.
"""
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal
from typing import Optional, List, Dict, Pattern, Tuple


@dataclass
class ParsedBill:
    """Result of parsing a credit card statement."""
    # Card info
    bank_name: str
    card_last_four: str
    
    # Statement info
    statement_date: date
    statement_month: str  # YYYY-MM format
    
    # Payment info
    due_date: date
    total_amount_due: Decimal
    minimum_due: Optional[Decimal] = None
    currency: str = "TWD"
    
    # Confidence
    confidence_score: float = 0.0  # 0.0 to 1.0
    extracted_fields: List[str] = None  # Which fields were successfully extracted
    
    # Raw data for debugging
    raw_text: str = ""
    
    def __post_init__(self):
        if self.extracted_fields is None:
            self.extracted_fields = []


class BaseParser(ABC):
    """
    Base class for bank statement parsers.
    
    Each bank-specific parser should inherit from this class
    and implement the required methods.
    """
    
    # Override in subclass
    BANK_NAME: str = ""
    BANK_CODE: str = ""
    
    # Common patterns that can be used by all parsers
    AMOUNT_PATTERN: Pattern = re.compile(r'[\d,]+\.?\d*')
    DATE_PATTERN: Pattern = re.compile(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}')
    
    def __init__(self):
        self.confidence_weights = {
            "bank_name": 0.1,
            "card_last_four": 0.1,
            "statement_date": 0.15,
            "due_date": 0.2,
            "total_amount_due": 0.3,
            "minimum_due": 0.15
        }
    
    @abstractmethod
    def can_parse(self, text: str) -> bool:
        """
        Check if this parser can handle the given text.
        
        Args:
            text: Extracted text from PDF/image
            
        Returns:
            True if this parser can parse the statement
        """
        pass
    
    @abstractmethod
    def parse(self, text: str) -> ParsedBill:
        """
        Parse the statement text and extract bill information.
        
        Args:
            text: Extracted text from PDF/image
            
        Returns:
            ParsedBill with extracted information
        """
        pass
    
    def extract_amount(self, text: str, patterns: List[str]) -> Optional[Decimal]:
        """
        Extract monetary amount using multiple regex patterns.
        
        Args:
            text: Text to search
            patterns: List of regex patterns to try
            
        Returns:
            Decimal amount or None if not found
        """
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
            if match:
                amount_str = match.group(1)
                # Remove commas and convert
                amount_str = amount_str.replace(',', '')
                try:
                    return Decimal(amount_str)
                except:
                    continue
        return None
    
    def extract_date(self, text: str, patterns: List[str]) -> Optional[date]:
        """
        Extract date using multiple regex patterns.
        
        Args:
            text: Text to search
            patterns: List of regex patterns to try
            
        Returns:
            date object or None if not found
        """
        for pattern in patterns:
            match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
            if match:
                date_str = match.group(1)
                try:
                    return self._parse_date(date_str)
                except:
                    continue
        return None
    
    def extract_card_last_four(self, text: str, patterns: List[str]) -> Optional[str]:
        """
        Extract last 4 digits of card number.
        
        Args:
            text: Text to search
            patterns: List of regex patterns to try
            
        Returns:
            Last 4 digits or None if not found
        """
        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                last_four = match.group(1)
                if len(last_four) == 4 and last_four.isdigit():
                    return last_four
        return None
    
    def calculate_confidence(self, parsed_bill: ParsedBill) -> float:
        """
        Calculate confidence score based on extracted fields.
        
        Args:
            parsed_bill: The parsed bill to evaluate
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        score = 0.0
        
        if parsed_bill.bank_name:
            score += self.confidence_weights["bank_name"]
        if parsed_bill.card_last_four:
            score += self.confidence_weights["card_last_four"]
        if parsed_bill.statement_date:
            score += self.confidence_weights["statement_date"]
        if parsed_bill.due_date:
            score += self.confidence_weights["due_date"]
        if parsed_bill.total_amount_due:
            score += self.confidence_weights["total_amount_due"]
        if parsed_bill.minimum_due:
            score += self.confidence_weights["minimum_due"]
        
        return round(score, 2)
    
    def _parse_date(self, date_str: str) -> date:
        """
        Parse date string in various formats.
        
        Supports:
        - YYYY-MM-DD
        - YYYY/MM/DD
        - YYYY年MM月DD日 (Chinese format)
        
        Args:
            date_str: Date string to parse
            
        Returns:
            date object
        """
        # Remove Chinese characters
        date_str = date_str.replace('年', '-').replace('月', '-').replace('日', '')
        
        # Try different formats
        formats = [
            "%Y-%m-%d",
            "%Y/%m/%d",
            "%Y-%m-%d",
            "%Y%m%d"
        ]
        
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt).date()
            except ValueError:
                continue
        
        raise ValueError(f"Could not parse date: {date_str}")
    
    def clean_text(self, text: str) -> str:
        """
        Clean and normalize extracted text.
        
        Args:
            text: Raw extracted text
            
        Returns:
            Cleaned text
        """
        # Replace multiple spaces with single space
        text = re.sub(r'\s+', ' ', text)
        # Remove common OCR artifacts
        text = text.replace('｜', '|').replace('—', '-')
        return text.strip()


class BankDetector:
    """
    Detect which bank a statement belongs to.
    
    Uses keywords and patterns to identify the bank.
    """
    
    BANK_INDICATORS = {
        "CTBC": ["中國信託", "CTBC", "中信", "Chinatrust"],
        "Cathay United Bank": ["國泰世華", "Cathay", "CUB", "世華"],
        "Taishin Bank": ["台新", "Taishin", "TSBank", "Richart"],
    }
    
    @classmethod
    def detect_bank(cls, text: str) -> Optional[str]:
        """
        Detect bank from statement text.
        
        Args:
            text: Extracted statement text
            
        Returns:
            Bank name or None if unable to detect
        """
        text_lower = text.lower()
        
        scores = {}
        for bank, indicators in cls.BANK_INDICATORS.items():
            score = 0
            for indicator in indicators:
                if indicator.lower() in text_lower:
                    score += 1
            scores[bank] = score
        
        # Return bank with highest score (must have at least 1 match)
        if scores:
            best_match = max(scores, key=scores.get)
            if scores[best_match] > 0:
                return best_match
        
        return None
    
    @classmethod
    def get_all_keywords(cls) -> Dict[str, List[str]]:
        """Get all bank detection keywords."""
        return cls.BANK_INDICATORS
