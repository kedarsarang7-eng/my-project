import cv2
import numpy as np
import pytesseract
from PIL import Image
import re
import logging
import platform

# Set Tesseract Path for Windows if not in PATH
if platform.system() == "Windows":
    # Common default paths
    possible_paths = [
        r"C:\Program Files\Tesseract-OCR\tesseract.exe",
        r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
        r"C:\Users\User\AppData\Local\Tesseract-OCR\tesseract.exe"
    ]
    for p in possible_paths:
        try:
            with open(p, 'r') as f:
                pytesseract.pytesseract.tesseract_cmd = p
                break
        except:
            continue

logger = logging.getLogger("BillProcessor")

class BillProcessor:
    def __init__(self):
        pass

    def enhance_image(self, image_path):
        """
        Applies CamScanner-like enhancements:
        - Grayscale
        - Adaptive Thresholding (Magic Color effect)
        - Denoising
        """
        try:
            img = cv2.imread(str(image_path))
            
            # 1. Grayscale
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            
            # 2. Denoise
            denoised = cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)
            
            # 3. Adaptive Threshold (binarization) - creates the high-contrast "scan" look
            # binary = cv2.adaptiveThreshold(denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
            
            # Or assume the user already cropped it well and just sharpen:
            kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
            sharpened = cv2.filter2D(denoised, -1, kernel)
            
            return sharpened
        except Exception as e:
            logger.error(f"Enhancement failed: {e}")
            return None

    def extract_text(self, image_path):
        """
        Runs Tesseract OCR on the image.
        """
        try:
            # Check availability
            try:
                pytesseract.get_tesseract_version()
            except pytesseract.TesseractNotFoundError:
                return {"error": "Tesseract OCR not found. Please install it."}

            # Enhance first
            processed_img_array = self.enhance_image(image_path)
            
            # Convert back to PIL for Tesseract
            if processed_img_array is not None:
                img = Image.fromarray(processed_img_array)
            else:
                img = Image.open(image_path)

            # OCR
            # --psm 6: Assume a single uniform block of text (good for bills)
            text = pytesseract.image_to_string(img, config='--psm 6')
            
            return text
        except Exception as e:
            logger.error(f"OCR failed: {e}")
            return ""

    def parse_bill(self, raw_text):
        """
        Extracts structured data from raw bill text using Regex & Heuristics.
        """
        data = {
            "shop_name": None,
            "date": None,
            "total": 0.0,
            "items": [],
            "gstin": None
        }
        
        lines = raw_text.split('\n')
        lines = [line.strip() for line in lines if line.strip()]

        if not lines:
            return data

        # 1. Shop Name (Heuristic: First non-empty, non-date line)
        if len(lines) > 0:
            data["shop_name"] = lines[0]

        # 2. Date Regex
        date_pattern = r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})'
        for line in lines:
            match = re.search(date_pattern, line)
            if match:
                data["date"] = match.group(1)
                break

        # 3. Total Amount Regex
        # Look for "Total", "Net", "Grand" followed by numbers
        total_pattern = r'(?i)(total|net|amount|payable|due).*?(\d+[.,]\d{2})'
        
        # Reverse search (totals usually at bottom)
        for line in reversed(lines):
            match = re.search(total_pattern, line)
            if match:
                try:
                    amount_str = match.group(2).replace(',', '')
                    data["total"] = float(amount_str)
                    break
                except:
                    continue
        
        # 4. GSTIN
        gst_pattern = r'\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}'
        for line in lines:
            match = re.search(gst_pattern, line)
            if match:
                data["gstin"] = match.group(0)
                break

        # 5. Items (Hardest part without AI models)
        # Attempt to find lines with structure: TEXT ... NUMBER
        # Skipping simplified item extraction for now to keep it robust. 
        # Just returning lines as potential items if needed or rely on Frontend "Editing"
        
        return data

bill_processor = BillProcessor()
