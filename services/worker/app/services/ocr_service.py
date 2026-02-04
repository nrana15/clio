"""
OCR (Optical Character Recognition) service using Tesseract.
"""
from typing import Optional, List
from io import BytesIO
import structlog

import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
import pdf2image

logger = structlog.get_logger()


class OCRService:
    """Extract text from images and scanned PDFs using Tesseract OCR."""
    
    # Supported languages for Tesseract
    DEFAULT_LANG = "chi_tra+chi_sim+eng"  # Traditional Chinese, Simplified, English
    
    def __init__(self, lang: str = None):
        self.lang = lang or self.DEFAULT_LANG
        self.logger = logger.bind(service="ocr")
    
    def extract_from_image(self, image_content: bytes, preprocess: bool = True) -> dict:
        """
        Extract text from image bytes.
        
        Args:
            image_content: Raw image bytes
            preprocess: Whether to apply image preprocessing
            
        Returns:
            dict with keys: text, confidence, success, error
        """
        try:
            image = Image.open(BytesIO(image_content))
            
            if preprocess:
                image = self._preprocess_image(image)
            
            # Perform OCR
            text = pytesseract.image_to_string(image, lang=self.lang)
            
            # Get confidence data
            confidence = self._calculate_confidence(image)
            
            self.logger.info(
                "ocr_extraction_success",
                text_length=len(text),
                confidence=confidence
            )
            
            return {
                "success": True,
                "text": text.strip(),
                "confidence": confidence,
                "error": None
            }
            
        except Exception as e:
            self.logger.error("ocr_extraction_failed", error=str(e))
            return {
                "success": False,
                "text": "",
                "confidence": 0.0,
                "error": str(e)
            }
    
    def extract_from_pdf(self, pdf_content: bytes, dpi: int = 300) -> dict:
        """
        Extract text from scanned PDF by converting to images.
        
        Args:
            pdf_content: Raw PDF bytes
            dpi: DPI for PDF to image conversion
            
        Returns:
            dict with keys: text, pages, confidence, success, error
        """
        try:
            # Convert PDF pages to images
            images = pdf2image.convert_from_bytes(
                pdf_content,
                dpi=dpi,
                fmt='png'
            )
            
            all_text = []
            confidences = []
            
            for i, image in enumerate(images):
                # Preprocess image
                processed_image = self._preprocess_image(image)
                
                # Perform OCR
                text = pytesseract.image_to_string(processed_image, lang=self.lang)
                all_text.append(text)
                
                # Get confidence for this page
                confidences.append(self._calculate_confidence(processed_image))
                
                self.logger.debug(f"ocr_page_processed", page=i+1, page_confidence=confidences[-1])
            
            combined_text = "\n".join(all_text)
            avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0
            
            self.logger.info(
                "ocr_pdf_extraction_success",
                pages=len(images),
                text_length=len(combined_text),
                avg_confidence=avg_confidence
            )
            
            return {
                "success": True,
                "text": combined_text,
                "pages": all_text,
                "page_count": len(images),
                "confidence": avg_confidence,
                "error": None
            }
            
        except Exception as e:
            self.logger.error("ocr_pdf_extraction_failed", error=str(e))
            return {
                "success": False,
                "text": "",
                "pages": [],
                "page_count": 0,
                "confidence": 0.0,
                "error": str(e)
            }
    
    def _preprocess_image(self, image: Image.Image) -> Image.Image:
        """
        Apply preprocessing to improve OCR accuracy.
        
        Steps:
        1. Convert to grayscale
        2. Enhance contrast
        3. Denoise (mild blur)
        4. Thresholding for sharp text
        """
        # Convert to grayscale
        if image.mode != 'L':
            image = image.convert('L')
        
        # Enhance contrast
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(2.0)
        
        # Enhance sharpness
        enhancer = ImageEnhance.Sharpness(image)
        image = enhancer.enhance(1.5)
        
        # Apply mild denoising
        image = image.filter(ImageFilter.MedianFilter(size=3))
        
        return image
    
    def _calculate_confidence(self, image: Image.Image) -> float:
        """
        Calculate OCR confidence score.
        
        Returns confidence as a float between 0.0 and 1.0.
        """
        try:
            # Get detailed data including confidence
            data = pytesseract.image_to_data(image, lang=self.lang, output_type=pytesseract.Output.DICT)
            
            confidences = []
            for conf in data['conf']:
                if conf != -1:  # -1 means no text
                    confidences.append(conf)
            
            if not confidences:
                return 0.0
            
            # Average confidence (Tesseract returns 0-100)
            avg_conf = sum(confidences) / len(confidences)
            return round(avg_conf / 100.0, 2)
            
        except Exception as e:
            self.logger.error("confidence_calculation_failed", error=str(e))
            return 0.0
    
    def is_scanned_pdf(self, pdf_content: bytes) -> bool:
        """
        Check if a PDF is scanned (image-based) or text-based.
        
        Returns True if the PDF appears to be scanned (no extractable text).
        """
        try:
            import fitz
            doc = fitz.open(stream=pdf_content, filetype="pdf")
            
            # Check first few pages for text
            total_text = ""
            for page_num in range(min(3, len(doc))):
                page = doc.load_page(page_num)
                total_text += page.get_text()
            
            doc.close()
            
            # If very little text, likely scanned
            return len(total_text.strip()) < 100
            
        except Exception as e:
            self.logger.error("pdf_scan_check_failed", error=str(e))
            return True  # Assume scanned if we can't determine


# Singleton instance
_ocr_service = None

def get_ocr_service(lang: str = None) -> OCRService:
    """Get OCR service singleton."""
    global _ocr_service
    if _ocr_service is None:
        _ocr_service = OCRService(lang=lang)
    return _ocr_service
