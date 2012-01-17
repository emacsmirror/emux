;;; emux-session.el --- Emacs Lisp Behaviour-Driven Development framework

;; Copyright (C) 2011 atom smith

;; Author: atom smith
;; URL: http://trickeries.com/emux
;; Created: 19 Jan 2011
;; Version: 0.1
;; Keywords: terminal multiplexer

;; This file is NOT part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3, or (at your option) any later
;; version.

;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with Emacs; see the file COPYING, or type `C-h C-c'. If not,
;; write to the Free Software Foundation at this address:

;; Free Software Foundation
;; 51 Franklin Street, Fifth Floor
;; Boston, MA 02110-1301
;; USA

;;; Commentary:

;;

(require 'emux-screen)

(defun emux-sessions ()
  (emux-get 'sessions))

(defun emux-session-create (&optional properties)
  (interactive)
  (let ((session (gensym "emux-session-")))
    (setplist session properties)
    (emux-set
     'sessions
     (cons
      session
      (emux-get 'sessions)))
    (emux-session-current session)
    (unless (emux-session-get :name)
      (emux-session-set :name (read-from-minibuffer "session name: ")))))

(defun emux-session-get (property &optional session)
  (let ((session (or session (emux-session-current))))
    (get session property)))

(defun emux-session-set (property value &optional session)
  (let ((session (or session (emux-session-current))))
    (put session property value)))

(defun emux-session-current (&optional session)
  (if session
      (emux-set 'current-session session))
  (emux-get 'current-session))

(defun emux-session-switch (&optional session)
  (interactive)
  (let ((switch-to-session
         (or
          session
          (emux-session-from-name
           (emux-completing-read
            "session: "
            (mapcar (lambda (symbol)
                      (get symbol :name))
                    (emux-get 'sessions)))))))
    (emux-session-current switch-to-session)))

(defun emux-session-from-name (name)
  (let ((found-session nil))
    (mapc (lambda (session)
            (if (equal name (emux-session-get :name session))
                (setf found-session session)))
          (emux-get 'sessions))
    found-session))

(defun emux-session-set-default-directory (path)
  (interactive "Dsession default directory: ")
  (emux-session-set :default-directory path))

(defun emux-session-destroy (&optional session)
  (interactive)
  (if (yes-or-no-p "Really destroy session along with all screens and terminals / processes?")
      (let ((session (or session (emux-session-current))))
        (mapc (lambda (screen)
                (emux-screen-destroy screen))
              (emux-session-get :screens session))
        (emux-set 'sessions (remove session (emux-get 'sessions)))
        (if (eq session (emux-session-current))
            (emux-session-current (car (emux-get 'sessions)))))))

(defadvice emux-screen-create (after emux-session-screen-create activate)
  (emux-session-set
   :screens
   (cons (emux-screen-current) (emux-session-get :screens))))

(defadvice emux-screen-switch (around emux-session-screen-switch activate)
  (flet ((emux-screens () (emux-session-get :screens)))
    ad-do-it))

(defadvice emux-terminal-create (around emux-session-default-directory activate)
  (let
      ((default-directory
         (or
          (emux-session-get :default-directory)
          default-directory)))
    ad-do-it))

(defadvice emux-terminal-rename (around emux-session-terminal-rename activate)
  (let ((name (format "%s/%s" (emux-session-get :name) name)))
    ad-do-it))

(defadvice emux-screen-current (around emux-session-current-screen activate)
  (emux-session-set :current-screen ad-do-it))

(defun emux-session-buffers (&optional session)
  (let ((session (or session (emux-session-current))))
    (emux-flatten (mapcar (lambda (screen)
                            (emux-screen-get :buffers screen))
                          (emux-session-get :screens session)))))

(defun emux-global-buffers ()
  (emux-flatten
   (mapcar
    (lambda (session)
      (emux-session-buffers session))
    (emux-get 'sessions))))

(defun emux-jump-to-global-buffer ()
  (interactive)
  (let ((buffer (emux-completing-read
                 "jump to global buffer: "
                 (mapcar 'buffer-name (emux-global-buffers)))))
    (catch 'break
      (mapc (lambda (session)
              (mapc (lambda (screen)
                      (if (member (get-buffer buffer) (emux-screen-get :buffers screen))
                          (progn
                            (emux-session-switch session)
                            (emux-screen-switch screen)
                            (pop-to-buffer buffer)
                            (message
                             (format
                              "switched to session %s and screen %s"
                              (emux-session-get :name session)
                              (emux-screen-get :name screen)))
                            (throw 'break nil))))
                    (emux-session-get :screens session)))
            (emux-sessions)))))

(defun emux-jump-to-session-buffer ()
  (interactive)
  (let ((buffer (emux-completing-read
                 "jump to session buffer: "
                 (mapcar 'buffer-name (emux-session-buffers (emux-session-current))))))
    (catch 'break
      (mapc (lambda (screen)
              (if (member (get-buffer buffer) (emux-screen-get :buffers screen))
                  (progn
                    (emux-screen-switch screen)
                    (pop-to-buffer buffer)
                    (throw 'break nil))))
            (emux-session-get :screens)))))

(provide 'emux-session)
