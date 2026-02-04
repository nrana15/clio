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

__all__ = [
    "BaseParser",
    "ParsedBill", 
    "BankDetector",
    "CTBCParser",
    "CathayUnitedParser",
    "TaishinParser",
    "GenericParser",
]
