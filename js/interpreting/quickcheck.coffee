S = require("./scheem")
A = require("assert")
T = require("../../testing/testsuite")

T.runSuite "Parsing", {},
    "Simple number": -> A.equal S.runScheem("5"), 5

T.runSuite "Evaluation", {},
    "Single built in expression": -> A.equal S.runScheem("(* 5 20)"), 100
    "Multiple expression -nested": -> A.equal S.runScheem("(* (* 3 10) (* 5 2))"), 300
    "Multiple expression -serial": -> A.equal S.runScheem("(begin (* 3 10) (* 5 2))"), 10
    "Multiple expression with var": -> A.equal S.runScheem("(begin (define x (* 3 10)) (* 5 x))"), 150
    "Multiple expression with lambda": -> A.equal(S.runScheem("""
         (begin (define x 5) (- ((lambda (x) (+ x 2)) 10) x))
        """), 7)
    "Multiple expression with let": -> A.equal(S.runScheem("""
         (begin (define x 5) (- (let ((x 10)) (+ x 2)) x))
        """), 7)

class TestBuffer
    constructor: ->
        @contents = ""
    write: (stuff) -> @contents += stuff

T.runSuite "Printing", {before: -> @b = new TestBuffer()},
    "Print symbol": ->
        S.runScheem """(print 'some-symbol)""", {stdout: @b}
        A.equal @b.contents, "some-symbol"
    "Print list": ->
        S.runScheem """(print '(a b c d))""", {stdout: @b}
        A.equal @b.contents, "(a b c d)"
    "Print hello world": ->
        S.runScheem """(println "Hello World!")""", {stdout: @b}
        A.equal @b.contents, "Hello World!\n"

T.runSuite "Procedures", {},
    "Assigning lambda":  -> A.equal S.runScheem("""
        (begin (define sq (lambda (x) (* x x))) (sq 5))
    """), 25
    "Assigning def":  -> A.equal S.runScheem("""
        (begin (define (sq x) (* x x)) (sq 5))
    """), 25
    "Multiple bindings":  -> A.equal S.runScheem("""(begin
        (define (mult x y) (* x y))
        (define a 10)
        (define b (+ 3 5))
        (mult a b)
    )"""), 80
    "Recursion": -> A.equal S.runScheem("""(begin
        (define (up-to m n f) (if (< m n) m (begin (f n) (up-to m (+ n 1) f))))
        (define c 0)
        (up-to 5 0 (lambda (n) (set! c (+ c 1))))
        c
    )"""), 6
    "fib": -> A.equal S.runScheem("""(begin
        (define (fib n) 
            (let ((ff (lambda (m c n-1 n-2)
              (if (= m c) (+ n-1 n-2) (ff m (+ c 1) (+ n-1 n-2) n-1)))))
            (if (< n 2) n (ff n 2 2 1))))
        (fib 30)
    )"""), 2178309

T.runSuite "Macros", {},
    "increment": -> A.equal S.runScheem("""(begin
        (define-syntax (++ x) (cons 'set! (cons x (list (list '+ x 1)))))
        (define c 0)
        (++ c)
        c
    )"""), 1

T.runSuite "HOF", {}
    'map': -> A.deepEqual S.runScheem("""(begin 
        (define (sq n) (* n n))
        (map sq (range 0 10))
    )"""), [0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
    'map with auto-currying': -> A.deepEqual S.runScheem("""
    (begin
        (define dbls (map (* 2)))
        (dbls (range 0 10))
    )
    """), [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
    'fold': -> A.equal S.runScheem("""(fold + (range 0 100))"""), 5050
    "Sum with fold": -> A.equal S.runScheem("""(begin
        (define (sum xs) (fold + xs))
        (sum (range 0 100))
    )"""), 5050
    "named filter": -> A.deepEqual S.runScheem("""
        (filter even? (range 0 10))
    """), [0, 2, 4, 6, 8, 10]
    "curried filter": -> A.deepEqual S.runScheem("""
            (filter (> 5) (range 0 10))
    """), [0, 1, 2, 3, 4]
    "composed curried filter": -> A.deepEqual S.runScheem("""
            (filter (. not (> 5)) (range 0 10))
    """), [5, 6, 7, 8, 9, 10]

T.runSuite "Cool Tools", {},
    'Composition': -> A.equal S.runScheem("""(begin
        (define (sq n) (* n n))
        ((. sq *) 3 4)
    )"""), 144
    "Implicit Currying": -> A.equal S.runScheem("""(begin
        (define sum (fold +))
        (sum (range 0 100))
    )"""), 5050
    "Always": -> A.deepEqual S.runScheem("""(begin
        (define (always n _) n)
        (map (always 1) (range 0 3))
    )"""), [1, 1, 1, 1]
    "length": -> A.equal S.runScheem("""(begin
        (define (always n _) n)
        (define (-len xs) (fold + (cons 0 (map (always 1) xs))))
        (-len (range 0 25))
    )"""), 26

T.runSuite "Complex stuff", {},
    "quicksort": -> A.deepEqual S.runScheem("""
        (begin
            (define unsorted '( 3 20 1 7 2 1 4 2 6 8 ))
            (define (always n _) n)
            (define (-len xs) (fold + (cons 0 (map (always 1) xs))))

            (define (quicksort xs) 
            (if (> 2 (-len xs))
                xs 
                (let ((x (car xs)) (rest (cdr xs)))
                (let ((lessers (quicksort (filter (> x) rest))) (greaters (quicksort (filter (<= x) rest))))
                    (conc lessers (cons x greaters))))))


            (quicksort unsorted)
        )
    """), [1, 1, 2, 2, 3, 4, 6, 7, 8, 20]
    "general sort": -> A.deepEqual S.runScheem("""
        (begin
            (define unsorted '( 3 20 1 7 2 1 4 2 6 8 ))
            (define (always n _) n)
            (define (-len xs) (fold + (cons 0 (map (always 1) xs))))

            (define (sort f xs) 
              (if (> 2 (-len xs))
                xs 
                (let ((x (car xs)) (rest (cdr xs)))
                  (let ( (lessers (sort f (filter (f x) rest))) (greaters (sort f (filter (. not (f x)) rest))) )
                    (conc lessers (cons x greaters))))))

            (sort > unsorted)
        )
    """), [1, 1, 2, 2, 3, 4, 6, 7, 8, 20]
    "reversed sort": -> A.deepEqual S.runScheem("""
        (begin
            (define unsorted '( 3 20 1 7 2 1 4 2 6 8 ))
            (define (always n _) n)
            (define (-len xs) (fold + (cons 0 (map (always 1) xs))))

            (define (sort f xs) 
              (if (> 2 (-len xs))
                xs 
                (let ((x (car xs)) (rest (cdr xs)))
                  (let ( (lessers (sort f (filter (f x) rest))) (greaters (sort f (filter (. not (f x)) rest))) )
                    (conc lessers (cons x greaters))))))

            (sort < unsorted)
        )
    """), [20, 8, 7, 6, 4, 3, 2, 2, 1, 1]
    "reverse": -> A.deepEqual S.runScheem("""
    (begin
      (define (always n _) n)
      (define (-len xs) (fold + (cons 0 (map (always 1) xs))))
      (define (reverse xs)
        (if (> 2 (-len xs)) 
          xs 
          (let ( (x (car xs)) (tail (cdr xs)) )
            (conc (reverse tail) (list x)))))
      (reverse (range 0 20))
    )
    """), [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    "And with macros": -> A.deepEqual S.runScheem("""
      (begin
        (define (always n _) n)
        (define (-len xs) (fold + (cons 0 (map (always 1) xs))))
        (define (reverse xs)
          (if (> 2 (-len xs)) 
            xs 
            (let ( (x (car xs)) (tail (cdr xs)) )
              (conc (reverse tail) (list x)))))
        (define-syntax (prepend x xs) (cons 'set! (cons xs (list (list 'cons x xs)))))
        (define-syntax (nigeb exprs ...) (cons 'begin (reverse exprs)))
        (define xs '())
        (nigeb
            (prepend 'foo xs)
            (prepend 'bar xs)
            (prepend 'baz xs)
        )
        xs
      )
    """), ["foo", "bar", "baz"]

T.runSuite "Pattern matching", {},
    "reverse with pattern matching": -> A.deepEqual S.runScheem("""
    (begin
      (define (reverse xs) (match xs (
          ((cons x tail) (conc (reverse tail) (list x)))
          (else          xs)
        )))

      (reverse (range 0 20))
    )
    """), [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]



###
S.runScheem """
(begin
    (define double (map (* 2)))
    (print (double (range 0 10)))
)
"""

S.runScheem """
(begin
    (define double (lambda (n) (* 2 n)))
    (define square (lambda (n) (* n n)))
    (print (map (. double square) (range 0 10)))
)
"""


S.runScheem """
(begin 
    (print "Expecting false")
    (print ((<= 10) 5))
    (print "Expecting true")
    (print ((<= 10) 15))
    (define opposite (. not <=))
    (print "Expecting true")
    (print ((opposite 10) 5))
    (print "Expecting false")
    (print ((opposite 10) 15))

)
"""

S.runScheem """
 (print '(a b c))
"""

S.runScheem """
 (print '())
"""

S.runScheem """
  (print '( 3 1 4 6 8 2 7 9 0 5 ))
"""

S.runScheem """
(begin
  (define xs '( 3 1 4 6 8 2 7 9 0 5 ))
  (print "XS is:")
  (print xs)
)
"""

S.runScheem """
(begin
    (print "Starting sort program")
    (define unsorted '( 3 1 4 6 8 2 7 9 0 5 ))
    (define none '())
    (define len (lambda (xs) (fold + (cons 0 (map (lambda (x) 1) xs)))))

    (define sort (lambda (f xs) 
        (if (= 0 (len xs)) 
            xs 
            (let ((x (car xs)) (rest (cdr xs)))
                 (let (
                        (smaller (sort f (filter (f          x) rest))) 
                        (greater (sort f (filter ((. not f)  x) rest))))
                      (conc smaller (cons x greater))
                 )
             )
        )
    ))

    (print "Sorting of empty list")
    (print (sort < none))
    (print "Sorting of unsorted list")
    (print (sort < unsorted))
    (print (sort > unsorted))
)
"""

S.runScheem """
    (print (push '(a b c) 'd))
"""

S.runScheem """
(begin
    (define len (lambda (xs) (fold + (cons 0 (map (lambda (x) 1) xs)))))
    (define reverse (lambda (xs) (if (= 0 (len xs)) xs
        (let ((x (car xs)) (rest (cdr xs))) 
             (push (reverse rest) x)))
    ))
    (print (reverse (range 0 10)))
)
"""

S.runScheem """
(begin
    (print "Now with function definition")
    (define (len     xs) (fold + (cons 0 (map (lambda (x) 1) xs))))
    (define (reverse xs)
        (if (= 0 (len xs)) 
          xs
          (let ((x (car xs)) (rest (cdr xs))) 
            (push (reverse rest) x)))
    )
    (print (reverse (range 0 10)))
)
"""

S.runScheem """
(begin
    (define len (lambda (xs) (fold + (cons 0 (map (lambda (x) 1) xs)))))
    (define reverse (lambda (xs) (if (= 0 (len xs)) xs
        (let ((x (car xs)) (rest (cdr xs))) 
             (push (reverse rest) x)))
    ))
    (define nigeb (macro (expr) (cons 'begin (reverse expr))))
    (print "Let go...")
    (nigeb 
        (print "What is first")
        (print "Will be last")
        (print "------------"))
)
"""

console.log S.evalScheem [
    "begin",
    ['define-syntax', ['apply', 'exs', '...'], 'exs'],
    ['print', ['quote', 'applying...']],
    ['apply', '+', 1, 2]
], {}



S.runScheem """
(let ((foo 2) (x (+ (- (* (foo 5)))))) (print "How did I get here?"))
"""

S.runScheem """
(let ((x (+ (- (* (foo))) 5))) (print "How did I get here?"))
"""
