;;;; sykosomatic.asd

(asdf:defsystem #:sykosomatic
  :serial t
  :depends-on (#:alexandria
               #:hunchentoot #:yaclml #:clws
               #:bordeaux-threads #:cl-ppcre
               #:jsown #:ironclad #:postmodern
               #:local-time
               #:string-case)
  :components
  ((:module src
            :serial t
            :components
            ((:module util
                      :serial t
                      :components
                      ((:file "util")
                       (:file "smug")
                       (:file "queue")
                       (:file "timer")))
             (:file "config")
             (:file "db")
             (:file "entity")
             (:file "vocabulary")
             (:file "account")
             (:module game-objects
                      :components
                      ((:file "nameable")
                       (:file "describable")))
             (:file "character")
             (:file "scene")
             (:file "session")
             (:file "websocket")
             (:file "parser")
             (:file "template")
             (:file "newchar-template")
             (:file "handler")
             (:module handlers
                      :components
                      ((:file "404")
                       (:file "index")
                       (:file "login")
                       (:file "logout")
                       (:file "misc")
                       (:file "newchar")
                       (:file "role")
                       (:file "scenes")
                       (:file "signup")
                       (:file "stage")
                       (:file "view-scene")))
             (:file "sykosomatic")))))
