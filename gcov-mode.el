;;; gcov-mode.el --- Show coverage stats in the fringe. -*- lexical-binding: t -*-

;; Copyright (C) 2020 Baolong Lin

;; Author: Baolong Lin
;; Maintainer: Baolong Lin
;; Created: 13 Mar 2020

;; Keywords: coverage gcov c
;; Package-Version:
;; Homepage: https://github.com/baolonglin/gcov-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.4"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This mode render the input gcov file for current buffer file
;; using fringe overlays.

;;; Code:

(require 'linum)

(defvar-local gcov-mode--not-covered-lines nil
  "Store line numbers which has not been covered."
  )
(defvar-local gcov-mode--covered-lines nil
  "Store line numbers which has been covered."
  )
(defvar gcov-mode-file-path nil
  "Coverage file path or function which return the coverage file path."
  )
(defconst gcov-mode-gcov-intermediate-line-re "^lcount:\\(\\([0-9]+\\),\\([0-9]+\\)\\)")

(defun gcov-mode-line-fringe (linenum)
  "Coverage mode line format for specified LINENUM."
  (let ((color (cond
		((member linenum gcov-mode--not-covered-lines) "red")
		((and (not (member linenum gcov-mode--not-covered-lines))
		      (member linenum gcov-mode--covered-lines)) "green")
		((and (not (member linenum gcov-mode--not-covered-lines))
		      (not (member linenum gcov-mode--covered-lines))) "")
		)))
    (propertize " " 'face `(:background ,color :foreground ""))
    )
  )

(defun gcov-mode-parse (coverage-file orig-file)
  "Parse COVERAGE-FILE for ORIG-FILE."
  (let ((covered nil)
	(not-covered nil)
	(more t)
	)
    (with-temp-buffer
      (insert-file-contents coverage-file)
      (goto-char (point-min))
      (when (search-forward (format "file:%s" orig-file) nil t)
	(end-of-line)
	(forward-line 1)
	(save-match-data
	  (while more
	    (cond ((looking-at gcov-mode-gcov-intermediate-line-re)
		   (if (> (string-to-number (match-string-no-properties 3)) 0)
		       (push (string-to-number (match-string-no-properties 2)) covered)
		     (push (string-to-number (match-string-no-properties 2)) not-covered)
		     )
		   (end-of-line)
		   (setq more (= 0 (forward-line 1)))
		   )
		  ((looking-at "^file:")
		   (setq more nil)
		   )
		  (t
		   (end-of-line)
		   (setq more (= 0 (forward-line 1))))
		  )
	    )
	  )
	)
      )
    (list covered not-covered)
    )
  )

(defun gcov-mode-load-data ()
  "Load coverage data from gcov file and parse into buffer."
  (let ((coverage-file (if (stringp gcov-mode-file-path) gcov-mode-file-path (funcall gcov-mode-file-path (buffer-file-name))))
	(parse-result nil)
	)
    (if (and coverage-file (file-exists-p coverage-file))
	(progn
	  (setq parse-result (gcov-mode-parse coverage-file (buffer-file-name)))
	  (setq gcov-mode--covered-lines (car parse-result))
	  (setq gcov-mode--not-covered-lines (car (cdr parse-result)))
	  )
      (message "Could not find coverage file %s" coverage-file)
	)
    )
  )

(defun gcov-mode-reload-data ()
  "Reload coverage data."
  (interactive)
  (setq gcov-mode--covered-lines nil)
  (setq gcov-mode--not-covered-lines nil)
  (gcov-mode-load-data)
  )

;;;###autoload
(define-minor-mode gcov-mode
  "Minor mode for gcov."
  :lighter " gcov"
  (if gcov-mode
      (progn
	(linum-mode t)
	(setf linum-format 'gcov-mode-line-fringe)
	(gcov-mode-load-data)
	)
    (setf linum-format 'dynamic)
    (linum-delete-overlays)
    (linum-mode -1))
  )

(provide 'gcov-mode)
;;; gcov-mode.el ends here
