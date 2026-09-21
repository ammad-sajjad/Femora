"""Refreshes the table of contents and page numbers in the generated Word report.

Run after scripts/build_report.py:  <python with pywin32> scripts/refresh_toc.py
python-docx writes the table of contents as an empty field, so Word itself has to fill it in.
Needs Microsoft Word installed. Close the document in Word first, or the save will fail.
"""
import sys
from pathlib import Path

import win32com.client

DOC = Path(__file__).resolve().parent.parent / "scope doument" / "Femora - Project Progress and Technical Report.docx"

word = win32com.client.DispatchEx("Word.Application")
word.Visible = False
word.DisplayAlerts = False
try:
    doc = word.Documents.Open(str(DOC))
    for toc in doc.TablesOfContents:
        toc.Update()
    doc.Fields.Update()
    doc.Repaginate()
    pages = doc.ComputeStatistics(2)  # wdStatisticPages
    words = doc.ComputeStatistics(0)  # wdStatisticWords
    doc.Save()
    doc.Close(False)
    print(f"refreshed {DOC.name}: {pages} pages, {words} words")
except Exception as exc:  # noqa: BLE001 - report and exit non-zero for the caller
    print(f"failed: {exc}", file=sys.stderr)
    sys.exit(1)
finally:
    word.Quit()
