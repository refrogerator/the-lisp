;; nice, a let!
;; (let ((a 2) (b 2)) (println b))
(define-macro let (a . b)
              (cons
                (list 'lambda (map first a)
                  (cons 'do b))
                (map second a)))

;; dotimes moment
;; (dotimes (i 10) (println i))
(define-macro dotimes (binding . body)
              (list 'let (list (list (first binding) (second binding)))
                    (cons 'while (cons (list '> (first binding) 0) 
                          (cons (list 'set! (first binding) (list '- (first binding) 1)) body)))))

;; list stuff
(define (produce-cdrs c final)
  (if (> c 0)
    (cons (cons 'cdr (produce-cdrs (- c 1) final)) nil)
    (cons final nil)))

(define-macro list-indexer (name cdrs)
              (list 'define (list name 'lst) 
                    (cons 'car (produce-cdrs cdrs 'lst))))

(list-indexer first   0)
(list-indexer second  1)
(list-indexer third   2)
(list-indexer fourth  3)
(list-indexer fifth   4)
(list-indexer sixth   5)
(list-indexer seventh 6)
(list-indexer eighth  7)
(list-indexer ninth   8)
