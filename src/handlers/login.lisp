(util:def-file-package #:sykosomatic.handler.login
  (:use :hunchentoot
        :sykosomatic.db
        :sykosomatic.handler
        :sykosomatic.session
        :sykosomatic.account)
  (:export :login))

(define-easy-handler (login :uri "/login") (email password)
  (case (request-method*)
    (:get
     (when-let ((account-id (current-account)))
       (push-error "Already logged in as ~A." (account-email account-id)))
     (with-form-errors (templ:render-template "login")))
    (:post
     (when (current-account)
       (redirect "/login"))
     (if-let ((account (validate-account email password)))
       (progn
         (start-persistent-session (id account))
         (logit "~A logged in." email)
         (redirect "/role"))
       (progn
         (push-error "Invalid login or password.")
         (redirect "/login"))))))
