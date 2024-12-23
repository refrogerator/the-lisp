;(define-macro let (a . b)
;              ;(cons (cons 'lambda (map car a)
;              (cons 'println (cons (cons 'quote a) nil)))

(define-macro infix (a)
              (list (car (cdr a)) (car a) (car (cdr (cdr a)))))

;(let ((a 4)) 'c)

(println (infix (1 + 2)))
(println (+ 1 2))

(println (vector 1 2 3 4))
(println true)
;(println #\c)
(println (fn (a) a))
(println (map (fn (a) (+ a 1)) (quote (1 2 3 4))))
(foreach println (quote (1 2 3 4)))

(println (symbol->string (quote amogus)))
(println (symbol->string 'amogus))
(println (string->symbol "amogus"))
(println (quote (1 . 2)))

(define a (list 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20))


(println a)

(cons 1 2)

;(gc)

(define v (vector 1 2 3))

;(gc)

(println v)

(println (vector-ref v 1))

;(define chuddy (lambda (impostor) 
;  (writeln (if impostor "your momma is the impostor" "your momma is not the impostor")) 
;  (chuddy (not impostor))))
;
;(chuddy true)


(println (cons 1 (cons 2 nil)))
(writeln "when the " (cons 1 2))
(println (list 1 2 3))
;(while true (car (cons 1 2)) (println a (cdr (cons 1 2))) (println "joE") a (gc))

(define amogus (fn (a) (fn () a)))
amogus
(amogus 2)
(println ((amogus 2)))
(define amogus (fn (a . b) (println a) (println b)))
(amogus 1 2)
(amogus 1 2 3 4 5)

(println 'impostor)
