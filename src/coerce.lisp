(defpackage #:apispec/coerce
  (:use #:cl
        #:apispec/schema
        #:apispec/validate
        #:apispec/utils
        #:parse-number)
  (:shadowing-import-from #:apispec/schema
                          #:number
                          #:float
                          #:double
                          #:integer
                          #:string
                          #:boolean
                          #:array

                          #:items
                          #:properties
                          #:name
                          #:type
                          #:nullable

                          #:parse-schema-definition)
  (:import-from #:cl-ppcre)
  (:import-from #:local-time)
  (:export #:coerce-failed
           #:coerce-data))
(in-package #:apispec/coerce)

(define-condition coerce-failed (error)
  ((value :initarg :value)
   (schema :initarg :schema))
  (:report (lambda (condition stream)
             (with-slots (value schema) condition
               (format stream "~S cannot be coerced to ~S"
                       value
                       (type-of schema))))))

(defgeneric coerce-data (value schema)
  (:method (value (schema symbol))
    (coerce-data value (make-schema schema)))
  (:method (value (schema cons))
    (coerce-data value
                 (multiple-value-bind (type args)
                     (parse-schema-definition schema)
                   (apply #'make-schema type args))))
  (:method (value (schema schema))
    (error 'coerce-failed
           :value value
           :schema schema))
  (:method :around (value (schema schema))
    (let ((result (call-next-method)))
      (validate-data result schema)
      result)))

;;
;; Number Types

(defmethod coerce-data ((value cl:number) (schema number))
  (typecase schema
    (integer (coerce value 'cl:integer))
    (float (coerce value 'cl:float))
    (double (coerce value 'cl:double-float))
    (otherwise value)))

(defmethod coerce-data ((value cl:string) (schema number))
  (coerce-data (parse-number value) schema))

(defmethod coerce-data ((value cl:string) (schema float))
  (coerce-data (parse-number value :float-format 'cl:single-float) schema))

(defmethod coerce-data ((value cl:string) (schema double))
  (coerce-data (parse-number value :float-format 'cl:double-float) schema))


;;
;; String Types

(defmethod coerce-data ((value cl:string) (schema string))
  (princ-to-string value))

(defmethod coerce-data ((value cl:string) (schema date))
  (check-type value cl:string)
  (ppcre:register-groups-bind ((#'parse-integer year month date))
      ("(\\d{4})-(\\d{2})-(\\d{2})" value)
    (local-time:universal-to-timestamp (encode-universal-time 0 0 0 date month year))))

(defmethod coerce-data ((value cl:string) (schema date-time))
  (check-type value cl:string)
  (local-time:parse-rfc3339-timestring value))

(defmethod coerce-data (value (schema boolean))
  (etypecase value
    (cl:string
     (cond
       ((equal value "true") t)
       ((equal value "false") nil)
       (t (error 'coerce-failed :value value :schema schema))))
    (cl:boolean value)))


;;
;; Array Type

(defmethod coerce-data (value (schema array))
  (if (slot-boundp schema 'items)
      (map 'vector
           (lambda (item)
             (coerce-data item (slot-value schema 'items)))
           value)
      (coerce value 'vector)))


;;
;; Object Type

(defmethod coerce-data (value (schema object))
  (check-type value association-list)

  (unless (slot-boundp schema 'properties)
    (return-from coerce-data value))

  (loop for (key . field-value) in value
        for prop = (find key (slot-value schema 'properties)
                         :key (lambda (x) (slot-value x 'name))
                         :test #'equal)
        collect
        (progn
          (unless prop
            (error 'validation-failed
                   :value value
                   :schema schema
                   :message (format nil "Undefined property: ~S" key)))
          (cons key
                (if field-value
                    (handler-case (coerce-data field-value (slot-value prop 'type))
                      (validation-failed (e)
                        (error 'validation-failed
                               :value value
                               :schema schema
                               :message (format nil "Validation failed at ~S:~%  ~S"
                                                key
                                                (slot-value e 'message)))))
                    nil)))))
