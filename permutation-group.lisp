;;;; permutation-group.lisp
;;;; Copyright (c) 2012 Robert Smith, Brendan Pawlowski

(in-package #:cl-permutation)

;;; A TRANSVERSAL SYSTEM (trans) is represented as a hash table, which
;;; takes a K and returns a table which takes a J and returns
;;; sigma_kj. That is
;;;
;;;    K -> (J -> sigma_kj)

(defstruct (perm-group (:conc-name perm-group.)
                       (:print-function perm-group-printer))
  generators
  strong-generators
  transversal-system)

(defun perm-group-printer (group stream depth)
  (declare (ignore depth))
  (print-unreadable-object (group stream :type t :identity nil)
    (format stream "of ~D generator~:p" (length (perm-group.generators group)))))

(defun safe-sigma (trans k j)
  (safe-gethash j (safe-gethash k trans)))

(defun trans-element-p (perm trans &optional (k (perm-size perm)))
  (or (= 1 k)
      (let ((j (perm-eval perm k)))
        (multiple-value-bind (k-val k-exists-p) (gethash k trans)
          (when k-exists-p
            (multiple-value-bind (j-val j-exists-p) (gethash j k-val)
              (when j-exists-p
                (trans-element-p (perm-compose (perm-inverse j-val) perm) 
                                 trans 
                                 (1- k)))))))))

(defun add-generator (perm sgs trans &optional (k (perm-size perm)))
  (declare (special *product-membership*))

  ;; Add the permutation to the generating set.
  (pushnew perm (gethash k sgs))
  
  (let ((redo nil))
    (loop
      (loop :for s :being :the :hash-values :of (gethash k trans)
            :do (dolist (tt (gethash k sgs))
                  (let ((prod (perm-compose tt s)))
                    (unless (or (and (hash-table-key-exists-p *product-membership* prod)
                                     (= k (gethash prod *product-membership*)))
                                (trans-element-p prod trans))
                     (setf (gethash prod *product-membership*) k)
                     
                     (multiple-value-setq (sgs trans)
                       (update-transversal prod sgs trans k))
                     
                     (setf redo t)))))
      
      ;; Break out?
      (unless redo
        (return-from add-generator (values sgs trans)))
      
      ;; Reset the REDO flag.
      (setf redo nil))))

(defun update-transversal (perm sgs trans &optional (k (perm-size perm)))
  (let ((j (perm-eval perm k)))
    (handler-case
        (let ((new-perm (perm-compose (perm-inverse (safe-sigma trans k j))
                                      perm)))
          (if (trans-element-p new-perm trans (1- k))
              (values sgs trans)
              (add-generator new-perm sgs trans (1- k))))
      (hash-table-access-error (c) 
        (declare (ignore c))
        (progn
          (setf (gethash j (gethash k trans)) perm)
          (values sgs trans))))))

(defun generate-perm-group (generators)
  "Generate a permutation group generated by the list of permutations
GENERATORS."
  (labels ((identity-table (n)
             "Make a hash table mapping N to the identity permutation
of size N"
             (let ((ht (make-hash-table)))
               (setf (gethash n ht)
                     (perm-identity n))
               
               ht)))

    (let ((n (maximum generators :key 'perm-size))
          (sgs (make-hash-table))
          (trans (make-hash-table))
          (*product-membership* (make-hash-table)))
      (declare (special *product-membership*))
      
      ;; Initialize TRANS to map I -> (I -> Identity(I)).
      (dotimes (i n)
        (setf (gethash (1+ i) trans) (identity-table (1+ i))))
      
      ;; Add the generators.
      (dolist (generator generators)
        (multiple-value-setq (sgs trans)
          (add-generator generator sgs trans)))
      
      ;; Return the group.
      (make-perm-group :generators generators
                       :strong-generators sgs
                       :transversal-system trans))))

(defun group-from (generators-as-lists)
  "Generate a permutation group from a list of generators, which are
represented as lists."
  (generate-perm-group (mapcar 'list-to-perm generators-as-lists)))

;;; TODO: Automatically try calculating size.
(defun group-from-cycles (generators-as-cycles size)
  "Generate a permutation group from a list of generators, which are
  represented as cycles."
  (generate-perm-group (mapcar (lambda (c)
                                 (from-cycles c size))
                               generators-as-cycles)))

(defun group-order (group)
  "Compute the order of the permutation group GROUP."
  (let ((transversals (perm-group.transversal-system group)))
    (product (hash-table-values transversals) :key 'hash-table-count)))

(defun group-element-p (perm group)
  "Decide if the permutation PERM is an element of the group GROUP."
  (trans-element-p perm (perm-group.transversal-system group)))

(defun random-group-element (group)
  "Generate a random element of the group GROUP."
  (loop :for v :being :the :hash-values :of (perm-group.transversal-system group)
        :collect (random-hash-table-value v) :into random-sigmas
        :finally (return (let ((maxlen (maximum random-sigmas :key 'perm-size)))
                           (reduce 'perm-compose (mapcar (lambda (s)
                                                           (perm-compose (perm-identity maxlen) s))
                                                         random-sigmas))))))
