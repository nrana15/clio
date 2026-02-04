"""
Unit tests for bank statement parsers
"""
import pytest
from datetime import date
from decimal import Decimal

from app.parsers.base import BaseParser, ParsedBill, BankDetector
from app.parsers.ctbc import CTBCParser
from app.parsers.cathay import CathayUnitedParser
from app.parsers.taishin import TaishinParser
from app.parsers.generic import GenericParser
from app.parsers import get_parser_for_statement


class TestBankDetector:
    """Tests for bank detection."""
    
    def test_detect_ctbc(self):
        """Test detecting CTBC statements."""
        text = "這是中國信託 CTBC 的信用卡帳單"
        bank = BankDetector.detect_bank(text)
        assert bank == "CTBC"
    
    def test_detect_cathay(self):
        """Test detecting Cathay United Bank statements."""
        text = "國泰世華銀行 Cathay United Bank 信用卡對帳單"
        bank = BankDetector.detect_bank(text)
        assert bank == "Cathay United Bank"
    
    def test_detect_taishin(self):
        """Test detecting Taishin Bank statements."""
        text = "台新銀行 Taishin Bank 信用卡帳單"
        bank = BankDetector.detect_bank(text)
        assert bank == "Taishin Bank"
    
    def test_detect_unknown(self):
        """Test detection with unknown bank."""
        text = "這是一個未知的帳單內容"
        bank = BankDetector.detect_bank(text)
        assert bank is None


class TestCTBCParser:
    """Tests for CTBC parser."""
    
    @pytest.fixture
    def parser(self):
        return CTBCParser()
    
    def test_can_parse_ctbc(self, parser):
        """Test that parser recognizes CTBC statements."""
        text = "中國信託銀行 CTBC CREDIT CARD STATEMENT"
        assert parser.can_parse(text) is True
    
    def test_cannot_parse_other_banks(self, parser):
        """Test that parser rejects non-CTBC statements."""
        text = "國泰世華銀行 Cathay statement"
        assert parser.can_parse(text) is False
    
    def test_parse_statement_date(self, parser):
        """Test extracting statement date."""
        text = """
        中國信託銀行
        帳單日期: 2024-01-15
        應繳金額: $5,000
        """
        bill = parser.parse(text)
        assert bill.statement_date == date(2024, 1, 15)
    
    def test_parse_taiwan_calendar_date(self, parser):
        """Test parsing Taiwanese calendar dates."""
        text = """
        中國信託
        民國 113 年 01 月 15 日
        """
        bill = parser.parse(text)
        assert bill.statement_date == date(2024, 1, 15)  # 113 + 1911 = 2024
    
    def test_parse_due_date(self, parser):
        """Test extracting due date."""
        text = """
        CTBC Credit Card
        繳款截止日: 2024-02-05
        """
        bill = parser.parse(text)
        assert bill.due_date == date(2024, 2, 5)
    
    def test_parse_amounts(self, parser):
        """Test extracting amounts."""
        text = """
        本期應繳金額: $12,345.67
        最低應繳金額: $1,000
        """
        bill = parser.parse(text)
        assert bill.total_amount_due == Decimal("12345.67")
        assert bill.minimum_due == Decimal("1000")
    
    def test_parse_card_last_four(self, parser):
        """Test extracting card last four digits."""
        text = """
        卡號末四碼: 1234
        CTBC Statement
        """
        bill = parser.parse(text)
        assert bill.card_last_four == "1234"
    
    def test_calculate_confidence(self, parser):
        """Test confidence calculation."""
        bill = ParsedBill(
            bank_name="CTBC",
            card_last_four="1234",
            statement_date=date(2024, 1, 15),
            statement_month="2024-01",
            due_date=date(2024, 2, 5),
            total_amount_due=Decimal("5000"),
            minimum_due=Decimal("1000"),
        )
        confidence = parser.calculate_confidence(bill)
        assert 0 <= confidence <= 1
        assert confidence > 0.5  # Should be high with all fields
    
    def test_parse_full_statement(self, parser):
        """Test parsing a complete statement."""
        text = """
        中國信託銀行 CHINATRUST COMMERCIAL BANK
        CREDIT CARD STATEMENT
        
        卡號末四碼: 5678
        帳單日期: 2024-02-01
        繳款截止日: 2024-02-20
        
        本期應繳金額: $25,000.00
        最低應繳金額: $2,500
        
        感謝您的使用
        """
        bill = parser.parse(text)
        assert bill.bank_name == "CTBC"
        assert bill.card_last_four == "5678"
        assert bill.total_amount_due == Decimal("25000.00")
        assert bill.minimum_due == Decimal("2500")
        assert bill.currency == "TWD"
        assert bill.confidence_score > 0.8


class TestCathayUnitedParser:
    """Tests for Cathay United Bank parser."""
    
    @pytest.fixture
    def parser(self):
        return CathayUnitedParser()
    
    def test_can_parse_cathay(self, parser):
        """Test that parser recognizes Cathay statements."""
        text = "國泰世華銀行 Cathay United Bank"
        assert parser.can_parse(text) is True
    
    def test_parse_statement_date(self, parser):
        """Test extracting statement date."""
        text = """
        國泰世華銀行
        結帳日: 2024-03-15
        """
        bill = parser.parse(text)
        assert bill.statement_date == date(2024, 3, 15)
    
    def test_parse_amounts(self, parser):
        """Test extracting amounts."""
        text = """
        國泰世華
        本期應繳總額: NT$8,888.88
        最低應繳金額: NT$1,000
        """
        bill = parser.parse(text)
        assert bill.total_amount_due == Decimal("8888.88")


class TestTaishinParser:
    """Tests for Taishin Bank parser."""
    
    @pytest.fixture
    def parser(self):
        return TaishinParser()
    
    def test_can_parse_taishin(self, parser):
        """Test that parser recognizes Taishin statements."""
        text = "台新銀行 Taishin Bank Richart"
        assert parser.can_parse(text) is True
    
    def test_parse_statement(self, parser):
        """Test parsing a Taishin statement."""
        text = """
        台新銀行
        卡號末四碼: 9999
        結帳日: 2024-04-01
        繳款截止日: 2024-04-21
        本期應繳總金額: $15,000
        """
        bill = parser.parse(text)
        assert bill.bank_name == "Taishin Bank"
        assert bill.card_last_four == "9999"
        assert bill.total_amount_due == Decimal("15000")


class TestGenericParser:
    """Tests for generic parser."""
    
    @pytest.fixture
    def parser(self):
        return GenericParser()
    
    def test_can_parse_anything(self, parser):
        """Test that generic parser accepts any text."""
        assert parser.can_parse("anything") is True
        assert parser.can_parse("") is True
    
    def test_parse_with_defaults(self, parser):
        """Test parsing with missing fields uses defaults."""
        text = "Some random text without useful data"
        bill = parser.parse(text)
        assert bill.bank_name == "Unknown Bank"
        assert bill.card_last_four == "0000"
        assert bill.total_amount_due == Decimal("0")
        assert bill.currency == "TWD"
    
    def test_parse_with_bank_detection(self, parser):
        """Test that generic parser detects bank when possible."""
        text = "This is a CTBC statement with some data"
        bill = parser.parse(text)
        assert bill.bank_name == "CTBC"
    
    def test_low_confidence_for_generic(self, parser):
        """Test that generic parser returns lower confidence."""
        text = "Some statement with Total: $1000"
        bill = parser.parse(text)
        assert bill.confidence_score <= 0.6  # Capped for generic parser


class TestGetParserForStatement:
    """Tests for parser selection."""
    
    def test_get_ctbc_parser(self):
        """Test selecting CTBC parser for CTBC statement."""
        text = "中國信託 CTBC statement"
        parser = get_parser_for_statement(text)
        assert isinstance(parser, CTBCParser)
    
    def test_get_cathay_parser(self):
        """Test selecting Cathay parser for Cathay statement."""
        text = "國泰世華 Cathay statement"
        parser = get_parser_for_statement(text)
        assert isinstance(parser, CathayUnitedParser)
    
    def test_get_taishin_parser(self):
        """Test selecting Taishin parser for Taishin statement."""
        text = "台新 Taishin statement"
        parser = get_parser_for_statement(text)
        assert isinstance(parser, TaishinParser)
    
    def test_get_generic_parser_as_fallback(self):
        """Test that generic parser is returned as fallback."""
        text = "Some unknown bank statement"
        parser = get_parser_for_statement(text)
        assert isinstance(parser, GenericParser)


class TestParsedBill:
    """Tests for ParsedBill dataclass."""
    
    def test_bill_creation(self):
        """Test creating a ParsedBill."""
        bill = ParsedBill(
            bank_name="Test Bank",
            card_last_four="1234",
            statement_date=date(2024, 1, 15),
            statement_month="2024-01",
            due_date=date(2024, 2, 5),
            total_amount_due=Decimal("5000.00"),
        )
        assert bill.bank_name == "Test Bank"
        assert bill.card_last_four == "1234"
        assert bill.currency == "TWD"  # Default value
    
    def test_extracted_fields_defaults(self):
        """Test that extracted_fields defaults to empty list."""
        bill = ParsedBill(
            bank_name="Test",
            card_last_four="1234",
            statement_date=date(2024, 1, 1),
            statement_month="2024-01",
            due_date=date(2024, 2, 1),
            total_amount_due=Decimal("100"),
        )
        assert bill.extracted_fields == []


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
