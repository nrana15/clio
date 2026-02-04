"""
PDF text extraction service using PyMuPDF (fitz).
"""
import re
from typing import List, Optional
from io import BytesIO
import structlog

import fitz  # PyMuPDF

logger = structlog.get_logger()


class PDFExtractionService:
    """Extract text and metadata from PDF files."""
    
    def __init__(self):
        self.logger = logger.bind(service="pdf_extraction")
    
    def extract_text(self, file_content: bytes) -> dict:
        """
        Extract text from PDF content.
        
        Returns:
            dict with keys: text, pages, metadata, success, error
        """
        try:
            doc = fitz.open(stream=file_content, filetype="pdf")
            
            all_text = []
            for page_num in range(len(doc)):
                page = doc.load_page(page_num)
                text = page.get_text()
                all_text.append(text)
            
            metadata = doc.metadata
            doc.close()
            
            combined_text = "\n".join(all_text)
            
            self.logger.info(
                "pdf_extraction_success",
                pages=len(all_text),
                text_length=len(combined_text)
            )
            
            return {
                "success": True,
                "text": combined_text,
                "pages": all_text,
                "page_count": len(all_text),
                "metadata": metadata,
                "error": None
            }
            
        except Exception as e:
            self.logger.error("pdf_extraction_failed", error=str(e))
            return {
                "success": False,
                "text": "",
                "pages": [],
                "page_count": 0,
                "metadata": {},
                "error": str(e)
            }
    
    def extract_text_from_page(self, file_content: bytes, page_number: int = 0) -> str:
        """Extract text from a specific page."""
        try:
            doc = fitz.open(stream=file_content, filetype="pdf")
            if page_number >= len(doc):
                doc.close()
                return ""
            
            page = doc.load_page(page_number)
            text = page.get_text()
            doc.close()
            return text
        except Exception as e:
            self.logger.error("page_extraction_failed", error=str(e), page=page_number)
            return ""
    
    def extract_tables(self, file_content: bytes) -> List[List[List[str]]]:
        """
        Extract tables from PDF (if any).
        Note: This is a basic implementation; complex tables may need specialized handling.
        """
        tables = []
        try:
            doc = fitz.open(stream=file_content, filetype="pdf")
            
            for page_num in range(len(doc)):
                page = doc.load_page(page_num)
                # Get text blocks which may represent table cells
                blocks = page.get_text("blocks")
                
                # Simple table detection based on aligned blocks
                if blocks:
                    tables.append(self._blocks_to_table(blocks))
            
            doc.close()
        except Exception as e:
            self.logger.error("table_extraction_failed", error=str(e))
        
        return tables
    
    def _blocks_to_table(self, blocks: list) -> List[List[str]]:
        """Convert text blocks to table structure."""
        # Sort blocks by y-coordinate (row), then x-coordinate (column)
        blocks.sort(key=lambda b: (round(b[1], -1), b[0]))  # Group by y, sort by x
        
        table = []
        current_row = []
        last_y = None
        
        for block in blocks:
            x0, y0, x1, y1, text, block_no, block_type = block
            
            if last_y is not None and abs(y0 - last_y) > 10:
                # New row
                if current_row:
                    table.append(current_row)
                current_row = [text.strip()]
            else:
                current_row.append(text.strip())
            
            last_y = y0
        
        if current_row:
            table.append(current_row)
        
        return table


# Singleton instance
_pdf_service = None

def get_pdf_service() -> PDFExtractionService:
    """Get PDF extraction service singleton."""
    global _pdf_service
    if _pdf_service is None:
        _pdf_service = PDFExtractionService()
    return _pdf_service
