(in-package :sykosomatic)

(defvar *runningp* nil)
(defun begin-shared-hallucination ()
  (when *runningp* (end-shared-hallucination) (warn "Restarting server."))
  (init-websockets 'sykosomatic.parser:parse-input)
  (init-hunchentoot)
  (setf *runningp* t))

(defun end-shared-hallucination ()
  (teardown-websockets)
  (teardown-hunchentoot)
  (setf *runningp* nil)
  t)
