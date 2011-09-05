(cl:defpackage #:sykosomatic.entity
  (:use :cl :postmodern :sykosomatic.db)
  (:export :list-modifiers :add-modifier :create-entity
           :entity-name :find-entity-by-name))
(cl:in-package #:sykosomatic.entity)

(defdao entity ()
  ((id :col-type serial :reader id)
   (comment :col-type (or db-null text)))
  (:keys id))

(defdao modifier ()
  ((id :col-type serial :reader id)
   (entity-id :col-type bigint :initarg :entity-id)
   (precedence :col-type bigint :initarg :precedence :col-default 0)
   (type :col-type text :initarg :type)
   (description :col-type (or db-null text) :initarg :description)
   (numeric-value :col-type (or db-null numeric) :initarg :numeric-value)
   (text-value :col-type (or db-null text) :initarg :text-value)
   (timestamp-value :col-type (or db-null timestamp) :initarg :timestamp-value))
  (:keys id))

(defun entity-id (entity)
  ;; Just numbers for now.
  entity)

(defun list-modifiers (entity)
  (query (:select :* :from 'modifier :where (:= 'entity-id (entity-id entity)))
         :alists))

(defun add-modifier (entity type &key
                     text-value numeric-value timestamp-value
                     precedence description)
  (with-transaction ()
    (make-dao 'modifier
              :entity-id (entity-id entity)
              :type type :text-value (or text-value :null)
              :numeric-value (or numeric-value :null)
              :timestamp-value (or timestamp-value :null)
              :description (or description :null)
              :precedence (or precedence 0))))

;; TODO - It might be useful to be able to quickly identify entities by some kind of name.  Perhaps
;;        we could just use a modifier, and have a modifier module that even gives multiple
;;        namespaces. :)
(defun create-entity (&key comment)
  (id (make-dao 'entity :comment (or comment :null))))

(defun entity-name (entity)
  (query (:select 'text-value :from 'modifier
                  :where (:and (:= 'entity-id (entity-id entity))
                               (:= 'type "entity-name")))
         :single))

(defun (setf entity-name) (new-value entity)
  (with-transaction ()
    (if (entity-name entity)
        (query (:update 'modifier
                        :set 'text-value new-value
                        :where (:and (:= 'entity-id (entity-id entity))
                                     (:= 'type "entity-name"))))
        (progn
          (assert (not (query (:select t :from 'modifier
                                       :where (:and (:= 'type "entity-name")
                                                    (:= 'text-value new-value)))
                              :single))
                  () "~S is not a globally unique entity name." new-value)
          (add-modifier entity "entity-name" :text-value new-value :description
                        "Unique human-usable identifier for entity.")))))

(defun find-entity-by-name (name)
  (query (:select 'entity-id :from 'modifier
                  :where (:and (:= 'type "entity-name")
                               (:= 'text-value name)))
         :single))
