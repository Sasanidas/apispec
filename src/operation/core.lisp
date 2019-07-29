(defpackage #:apispec/operation/core
  (:use #:cl
        #:apispec/utils)
  (:import-from #:apispec/operation/request-body
                #:request-body)
  (:import-from #:apispec/operation/response
                #:responses)
  (:import-from #:apispec/parameter
                #:parameter)
  (:export #:operation
           #:operation-tags
           #:operation-summary
           #:operation-description
           #:operation-id
           #:operation-parameters
           #:operation-request-body
           #:operation-responses
           #:operation-deprecated-p))
(in-package #:apispec/operation/core)

(declaim-safety)

;; TODO: 'externalDocs', 'callbacks', 'security' and 'servers'.
(defclass operation ()
  ((tags :type (proper-list string)
         :initarg :tags
         :initform nil
         :reader operation-tags)
   (summary :type (or string null)
            :initarg :summary
            :initform nil
            :reader operation-summary)
   (description :type (or string null)
                :initarg :description
                :initform nil
                :reader operation-description)
   (id :type (or string null)
       :initarg :id
       :initform nil
       :reader operation-id)
   (parameters :type (proper-list parameter)
               :initarg :parameters
               :initform nil
               :reader operation-parameters)
   (request-body :type (or request-body null)
                 :initarg :request-body
                 :initform nil
                 :reader operation-request-body)
   (responses :type responses
              :initarg :responses
              :initform (error ":responses is required for OPERATION")
              :reader operation-responses)
   (deprecated :type boolean
               :initarg :deprecated
               :initform nil
               :reader operation-deprecated-p)))

(undeclaim-safety)
