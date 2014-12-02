#lang typed/racket/base

(require racket/match
         racket/list
         math/flonum
         "ordered-set.rkt"
         "../flonum.rkt"
         "../utils.rkt")

(provide (all-defined-out))

(define-ordered-set
  #:names Prob prob
  #:types Prob
  #:predicates
  (λ (x) #t)
  (λ (x) #t)
  prob-0?
  prob-1?
  #:comparisons prob= prob<
  #:guards
  (λ (a b a? b?) #f)
  (λ (a b a? b?) #f)
  (λ (a b a? b?) (values a b a? b?))
  )

;; ===================================================================================================
;; More Prob-Interval ops

(: prob->singleton (-> Prob Plain-Prob-Set))
(define (prob->singleton x)
  (Plain-Prob-Interval x x #t #t))

(: prob-interval-fields (-> Nonempty-Prob-Interval (Values Prob Prob Boolean Boolean)))
(define (prob-interval-fields I)
  (if (probs? I)
      (values prob-0 prob-1 #t #t)
      (values (Plain-Prob-Interval-min I)
              (Plain-Prob-Interval-max I)
              (Plain-Prob-Interval-min? I)
              (Plain-Prob-Interval-max? I))))

(: prob-interval-measure (-> Prob-Interval Prob))
(define (prob-interval-measure I)
  (cond [(empty-prob-set? I)  prob-0]
        [(probs? I)   prob-1]
        [else
         (define p (prob- (Plain-Prob-Interval-max I) (Plain-Prob-Interval-min I)))
         (cond [(prob? p)  p]
               [else  (error 'prob-interval-measure "result is not a probability; given ~e" I)])]))

(: prob-next (-> Prob Prob))
(define (prob-next x)
  (Prob (flprob-fast-canonicalize (flnext* (Prob-value x)))))

(: prob-prev (-> Prob Prob))
(define (prob-prev x)
  (Prob (flprob-fast-canonicalize (flprev* (Prob-value x)))))

(: prob-interval-can-sample? (-> Nonempty-Prob-Interval Boolean))
(define (prob-interval-can-sample? I)
  (define-values (a b a? b?) (prob-interval-fields I))
  (not (and (not a?) (not b?) (prob= (prob-next a) b))))

(: prob-interval-sample-point (-> Nonempty-Prob-Interval (U Bad-Prob Prob)))
(define (prob-interval-sample-point I)
  (define-values (a b a? b?) (prob-interval-fields I))
  (let loop ()
    (define x (prob-random a b))
    (cond [(not (or (and (not a?) (prob= x a)) (and (not b?) (prob= x b))))  x]
          [(prob-interval-can-sample? I)  (loop)]
          [else  bad-prob])))

;; ===================================================================================================
;; More ops

(: prob-interval-list-measure (-> (Listof+2 Nonempty-Prob-Interval) Prob))
(define (prob-interval-list-measure Is)
  (for/fold ([q : Prob  prob-0]) ([I  (in-list Is)])
    (let ([q  (prob+ q (prob-interval-measure I))])
      (if (prob? q) q prob-1))))

(: prob-interval-list-probs (-> (Listof+2 Nonempty-Prob-Interval) (U #f (Listof+2 Prob))))
(define (prob-interval-list-probs Is)
  (define q (prob-interval-list-measure Is))
  (cond [(prob-0? q)  #f]
        [else
         (map/+2 (λ ([I : Nonempty-Prob-Interval])
                   (define p (prob/ (prob-interval-measure I) q))
                   (if (prob? p) p prob-1))
                 Is)]))

(: prob-set-measure (-> Prob-Set Prob))
(define (prob-set-measure I)
  (cond [(empty-prob-set? I)  prob-0]
        [(probs? I)  prob-1]
        [(Plain-Prob-Interval? I)   (prob-interval-measure I)]
        [else  (prob-interval-list-measure (Plain-Prob-Interval-List-elements I))]))

(: prob-set-sample-point (-> Nonempty-Prob-Set (U Bad-Prob Prob)))
(define (prob-set-sample-point I)
  (cond [(or (probs? I) (Plain-Prob-Interval? I))  (prob-interval-sample-point I)]
        [else
         (define q (prob-set-measure I))
         (define Is (filter prob-interval-can-sample? (Plain-Prob-Interval-List-elements I)))
         (cond [(empty? Is)  bad-prob]
               [(empty? (rest Is))  (prob-interval-sample-point (first Is))]
               [else
                (define ps (prob-interval-list-probs Is))
                (cond [ps  (define i (prob-random-index ps))
                           (prob-interval-sample-point (list-ref Is i))]
                      [else  bad-prob])])]))

(: prob-set-self-join (case-> (-> Nonempty-Prob-Set Nonempty-Prob-Interval)
                              (-> Prob-Set Prob-Interval)))
(define (prob-set-self-join I)
  (cond [(empty-prob-set? I)  empty-prob-set]
        [(or (probs? I) (Plain-Prob-Interval? I))  I]
        [else
         (define Is (Plain-Prob-Interval-List-elements I))
         (for/fold ([I : Nonempty-Prob-Interval  (prob-interval-join (first Is) (second Is))])
                   ([J  (in-list (rest (rest Is)))])
           (prob-interval-join I J))]))