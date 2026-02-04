"""
Bank statement parsers for CLIO.

This module contains parsers for different Taiwanese banks:
- CTBC (中國信託)
- Cathay United Bank (國泰世華)
- Taishin Bank (台新)
"""
from .base import BaseParser, ParsedBill, BankDetector
from .ctbc import CTBCParser
from .cathay import CathayUnitedParser
from .taishin import TaishinParser
from .generic import GenericParser

# Parser registry - order matters (specific parsers first, generic last)
PARSERS = [
    CTBCParser,
    CathayUnitedParser,
    TaishinParser,
    GenericParser,  # Always last as fallback
]


def get_parser_for_statement(text: str) -> BaseParser:
    """
    Get the appropriate parser for a statement.
    
    Args:
        text: Extracted text from the statement
        
    Returns:
        Parser instance that can handle the statement
    """
    for parser_class in PARSERS:
        parser = parser_class()
        if parser.can_parse(text):
            return parser
    
    # Should never reach here due to GenericParser
    return GenericParser()


__all__ = [
    "BaseParser",
    "ParsedBill",
    "BankDetector",
    "CTBCParser",
    "CathayUnitedParser",
    "TaishinParser",
    "GenericParser",
    "PARSERS",
    "get_parser_for_statement",
]
