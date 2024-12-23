(println (vector 1 2 3 4))
(println true)
;(println #\c)
(println (fn (a) a))
(println (map (fn (a) (+ a 1)) (quote (1 2 3 4))))
(foreach println (quote (1 2 3 4)))

(println (symbol->string (quote fart)))
(println (symbol->string 'fart))
(println (string->symbol "fart"))
(println (quote (1 . 2)))

(define a (list 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20))


(println a)

(cons 1 2)

;(gc)

(define v (vector 1 2 3))

;(gc)

(println v)

(println (vector-ref v 1))

;(define chuddy (lambda (poopy) 
;  (writeln (if poopy "your momma ate poopy" "your momma did not eat poopy")) 
;  (chuddy (not poopy))))
;
;(chuddy true)


(println (cons 1 (cons 2 nil)))
(writeln "i farted onto my " (cons 1 2))
(println (list 1 2 3))
;(while true (car (cons 1 2)) (println a (cdr (cons 1 2))) (println "joE") a (gc))

(define fart (fn (a) (fn () a)))
fart
(fart 2)
(println ((fart 2)))
(define fart (fn (a . b) (println a) (println b)))
(fart 1 2)
(fart 1 2 3 4 5)

(println 'impostor)
