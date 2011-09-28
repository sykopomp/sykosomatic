(cl:defpackage #:sykosomatic.game-objects.nameable
  (:use :cl :alexandria
        :sykosomatic.util
        :sykosomatic.db
        :sykosomatic.entity)
  (:export :add-name :base-name :full-name
           :recalculate-full-name :refresh-all-full-names))
(cl:in-package #:sykosomatic.game-objects.nameable)

;; Thank you, PCL
(defparameter *english-list*
  "~{~#[~;~a~;~a and ~a~:;~@{~a~#[~;, and ~:;, ~]~}~]~}")

(defun calculate-full-name (base-name use-article-p adjectives titles first-name suffix suffix-titles)
  (with-output-to-string (s)
    (when use-article-p (princ "a " s))
    (when adjectives (format s *english-list* (coerce adjectives 'list)) (princ " " s))
    (when titles (map nil (curry #'format s "~A ") titles))
    (when first-name (format s "~A " first-name))
    (princ base-name s)
    (when suffix (format s " ~A" suffix))
    (when suffix-titles (format s "~{, ~A~}" (coerce suffix-titles 'list))))  )

(defdao nameable ()
  ((entity-id bigint)
   (base-name text)
   (use-article-p boolean :col-default nil)
   (adjectives (or db-null text[]))
   (titles (or db-null text[]))
   (first-name (or db-null text))
   (suffix (or db-null text))
   (suffix-titles (or db-null text[]))
   (full-name text)))

(defun add-name (entity base-name &key
                 use-article-p adjectives titles
                 first-name suffix suffix-titles)
  (flet ((ensure-vector (maybe-vec)
           (if (vectorp maybe-vec)
               maybe-vec
               (coerce maybe-vec 'vector))))
    (with-db ()
      (id (make-dao 'nameable
                    :entity-id entity
                    :base-name base-name
                    :use-article-p use-article-p
                    :adjectives (if adjectives (ensure-vector adjectives) :null)
                    :titles (if titles (ensure-vector titles) :null)
                    :first-name (or first-name :null)
                    :suffix (or suffix :null)
                    :suffix-titles (if suffix-titles (ensure-vector suffix-titles) :null)
                    :full-name (calculate-full-name
                                base-name use-article-p adjectives titles
                                first-name suffix suffix-titles))))))

(defun base-name (entity)
  (db-query (:select 'base-name :from 'nameable :where (:= 'entity-id entity))
            :single))

(defun full-name (entity)
  (db-query (:select 'full-name :from 'nameable :where (:= 'entity-id entity))
            :single))

(defun recalculate-full-name (entity)
  (with-transaction ()
    (let ((full-name-args (db-query (:for-update
                                     (:select 'base-name 'use-article-p 'adjectives 'titles
                                              'first-name 'suffix 'suffix-titles
                                              :from 'nameable
                                              :where (:= 'entity-id entity)))
                                    :row)))
      (db-query (:update 'nameable :set
                         'full-name (apply #'calculate-full-name
                                           (substitute nil :null full-name-args)))))))

(defun refresh-all-full-names ()
  (with-transaction ()
    (doquery (:select 'entity-id :from 'nameable) (entity)
      (with-db (:reusep nil)
        (recalculate-full-name entity)))))

(defun test-names ()
  (flet ((test-case (expected nameable-alist)
           (let ((e (create-entity :comment expected)))
             (unwind-protect
                  (with-db ()
                    (apply #'make-dao 'nameable :entity-id e
                           (alist-plist
                            (mapcar (lambda (pair)
                                      (cons (intern (string (car pair)) :keyword)
                                            (cdr pair)))
                                    nameable-alist)))
                    (assert (string= (full-name e) expected) ()
                            "Full name was ~S" (full-name e)))
               (db-query (:delete-from 'nameable :where (:= 'entity-id e)))
               (db-query (:delete-from 'entity :where (:= 'id e)))))))
    (test-case "a little teapot"
               '((base-name . "teapot")
                 (use-article-p . t)
                 (adjectives . #("little"))))
    (test-case "a short and stout teapot"
               '((base-name . "teapot")
                 (use-article-p . t)
                 (adjectives . #("short" "stout"))))
    (test-case "a little, short, and stout teapot"
               '((base-name . "teapot")
                 (use-article-p . t)
                 (adjectives . #("little" "short" "stout"))))
    (test-case "a male servant" '((base-name . "servant")
                                  (use-article-p . t)
                                  (adjectives . #("male"))))
    (test-case "Godot" '((base-name . "Godot")))
    (test-case "John Doe" '((base-name . "Doe")
                            (first-name . "John")))
    (test-case "Count Chocula" '((base-name . "Chocula")
                                 (titles . #("Count"))))
    (test-case "Supreme Commander John Doe" '((base-name . "Doe")
                                              (first-name . "John")
                                              (titles . #("Supreme" "Commander"))))
    (test-case "Commander John Doe Jr" '((base-name . "Doe")
                                         (first-name . "John")
                                         (titles . #("Commander"))
                                         (suffix . "Jr")))
    (test-case "Commander John Doe, PhD" '((base-name . "Doe")
                                           (first-name . "John")
                                           (titles . #("Commander"))
                                           (suffix-titles . #("PhD"))))
    (test-case "Commander John Doe Jr, PhD, Esq" '((base-name . "Doe")
                                                   (first-name . "John")
                                                   (titles . #("Commander"))
                                                   (suffix . "Jr")
                                                   (suffix-titles . #("PhD" "Esq"))))
    ;; TODO, maybe
    #+nil(test-case "the captain of the guard" '())))
