(util:def-file-package #:sykosomatic.components.describable
  (:use :sykosomatic.db
        :sykosomatic.entity)
  (:export :noun
           :adjectives
           :add-feature
           :remove-feature
           :list-features
           :nickname
           :base-description
           :short-description))

(defdao noun ()
  ((entity-id bigint)
   (noun text)))

(defun noun (entity)
  (db-query (:select 'noun :from 'noun :where (:= 'entity-id entity)) :single))
(defun (setf noun) (new-value entity)
  (with-transaction ()
    (cond ((null new-value)
           (db-query (:delete-from 'noun :where (:= 'entity-id entity))))
          ((noun entity)
           (db-query (:update 'noun :set 'noun new-value :where (:= 'entity-id entity))))
          (t
           (insert-row 'noun :entity-id entity :noun new-value))))
  new-value)

(defdao adjective ()
  ((entity-id bigint)
   (adjective text)))

(defun adjectives (entity)
  (db-query (:select 'adjective :from 'adjective :where (:= 'entity-id entity))
            :column))
(defun (setf adjectives) (new-value entity)
  (with-transaction ()
    (db-query (:delete-from 'adjective :where (:= 'entity-id entity)))
    (map nil (lambda (new-adj) (insert-row 'adjective :entity-id entity :adjective new-adj))
         new-value))
  new-value)

(defdao feature ()
  ((entity-id bigint)
   (feature-id bigint)))

(defun add-feature (entity feature)
  (with-transaction ()
    (unless (db-query (:select t :from 'feature :where (:and (:= 'entity-id entity)
                                                             (:= 'feature-id feature)))
                      :single)
      (insert-row 'feature :feature-id feature :entity-id entity))))
(defun remove-feature (entity feature)
  (db-query (:delete-from 'feature :where (:and (:= 'entity-id entity)
                                                (:= 'feature-id feature)))))
(defun list-features (entity)
  (db-query (:select 'feature-id :from 'feature :where (:= 'entity-id entity))
            :column))

(defun base-description (entity &key (include-features-p t))
  (when-let (result (db-query (:select 'n.noun
                                       ;; Pray for proper ordering. :(
                                       (:raw "array_agg(DISTINCT a.adjective)")
                                       (:raw "array_agg(DISTINCT f.feature_id)")
                                       :from (:as 'noun 'n)
                                       :left-join (:as 'adjective 'a)
                                       :on (:= 'a.entity-id 'n.entity-id)
                                       :left-join (:as 'feature 'f)
                                       :on (:= 'f.entity-id 'n.entity-id)
                                       :where (:= 'n.entity-id entity)
                                       :group-by 'noun)
                              :row))
    (destructuring-bind (noun adjectives features) result
      (with-output-to-string (s)
        (princ "a " s)
        (when-let (adjs (coerce (remove :null adjectives) 'list))
          (format s (concatenate 'string *english-list-format-string* " ") adjs))
        (princ noun s)
        (when include-features-p
          (when-let (feature-descs (loop for feature across features
                                      for feature-desc = (unless (eq :null feature)
                                                           (base-description feature
                                                                             :include-features-p nil))
                                      when feature-desc
                                      collect feature-desc))
            (format s " with ")
            (format s *english-list-format-string* feature-descs)))))))

(defdao nickname ()
  ((entity-id bigint)
   (observer-id bigint)
   (nickname text)))

(defun nickname (observer entity)
  (db-query (:select 'nickname :from 'nickname
                     :where (:and (:= 'observer-id observer)
                                  (:= 'entity-id entity)))
            :single))

(defun (setf nickname) (new-value observer entity)
  (with-transaction ()
    (cond ((null new-value)
           (db-query (:delete-from 'nickname :where (:and
                                                     (:= 'observer-id observer)
                                                     (:= 'entity-id entity)))))
          ((nickname observer entity)
           (db-query (:update 'nickname :set 'nickname new-value
                              :where (:and
                                      (:= 'observer-id observer)
                                      (:= 'entity-id entity)))))
          (t
           (insert-row 'nickname
                       :entity-id entity
                       :observer-id observer
                       :nickname new-value))))
  new-value)

(defun all-nicknames (entity)
  (db-query (:select 'nickname 'observer-id :from 'nickname
                     :where (:= 'entity-id entity))
            :plists))

(defun short-description (observer entity)
  (or (nickname observer entity)
      (base-description entity)))
