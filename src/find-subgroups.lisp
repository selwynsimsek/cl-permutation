;;;; find-subgroups.lisp
;;;;
;;;; Copyright (c) 2015 Robert Smith

(in-package #:cl-permutation)

;;; An "exponent subgroup" of a group
;;;
;;;    G = <g_1, ..., g_n> is a
;;;
;;; subgroup generated by <g_1^k_1, ..., g_n^k_n> where
;;;
;;;    0 <= k_i < order(g_i) - 1.
;;;
;;; The n-tuple (k_1, ..., k_n) is called the "exponent vector".

(defun generator-orders (g)
  "Return the orders of each generator of the group G."
  (check-type g perm-group)
  (map 'vector
       #'perm:perm-order
       (perm-group.generators g)))

(defun generator-exponent-set (g)
  "Return a combinatorial specification suitable for searching for subgroups of the group G.

The specification specifies vectors of exponents to the group's generators, which may be used to generate some subgroups of the group."
  (check-type g perm-group)
  ;; We subtract 1 from the orders so we do not search subgroups of G
  ;; generated by a set of inverse permutations, because of the
  ;; following fact:
  ;;
  ;;    G = <g_1, g_2, ..., g_n>
  ;;      = <..., g_i^-1, ...>
  (let ((orders (map 'vector #'1- (generator-orders g))))
    (vector-to-mixed-radix-spec orders)))

(defun subgroup-from-exponent-vector (g v)
  "Generate a subgroup of the group G given the exponent vector V (which was possibly generated by some combinatorial spec, perhaps via #'GENERATOR-EXPONENT-SET)."
  (let* ((gens (perm-group.generators g))
         ;; Compute the list of generators of the subgroup, possibly
         ;; containing identity perms.
         (sub-gens (map 'list #'perm-expt gens v)))
    (generate-perm-group (remove-if #'perm-identity-p sub-gens))))

(defun map-exponent-subgroups (f group)
  "Map the unary function F across all exponent subgroups of the group GROUP."
  (flet ((process-vector (ignore exponent-vector)
           (declare (ignore ignore))
           (funcall f (subgroup-from-exponent-vector group
                                                     exponent-vector))))
    (map-spec #'process-vector (generator-exponent-set group))))

(defun suitable-subgroup-p (g)
  "Is the group G (which is presumably a subgroup of some other group) suitable for further computation?"
  (typep (group-order g) 'fixnum))

(defun map-suitable-subgroups (f group)
  "Map the unary function F across all suitable subgroups of the group GROUP."
  (flet ((process-subgroup (subgroup)
           (when (suitable-subgroup-p subgroup)
             (funcall f subgroup))))
    (map-exponent-subgroups #'process-subgroup group)))