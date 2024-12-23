package main

import "core:fmt"
import "core:os"
import "core:bufio"
import "core:strings"

main :: proc() {
    file, err := os.read_entire_file_from_filename("tests/joe.lisp")
    if !err {
        fmt.println("file could not be read")
        os.exit(1)
    }
    defer delete(file);

    state := createInterpreter()

    temp := read(string(file), state)
    evalI(temp, state)

    r: bufio.Reader
    buffer: [1024]byte
    bufio.reader_init_with_buf(&r, os.stream_from_handle(os.stdin), buffer[:])
    defer bufio.reader_destroy(&r)
    for {
        fmt.print("> ")
        line, err := bufio.reader_read_string(&r, '\n')
        if err != nil {
            break
        }
        defer delete(line)
        line = strings.trim_right(line, "\r")
        readed := read(line, state)
        //println(readed, state)
        println(evalI(readed, state), state)
        //println(read(line, state), state)
        //println(evalI(read(line, state), state), state)
        //mark_sweep_run_gc(cast(^MarkSweepGC)state.allocator.data)
    }

    //printn(consNode(strNode("impostor"), consNode(numNode(5), strNode("fart"))), &state)
    //printn((read("(+ \"amogus sus\" 311490)", &state)), &state)
    //dolist(read("1 2", &state), printn, &state)
    //dolist(read("a a a", &state), proc(node: ^Node, s: ^InterpreterState) { printn(eval(node, s), s) }, &state)

    //evalLP(read("(+ (+ 2 3) (+ 1 2))", &state), &state)
    //evalLP(read("(define a 4) a", &state), &state)
    //evalLP(read("(car (cons 1 2))", &state), &state)
    //evalLP(read("(cdr (cons 1 2))", &state), &state)
    //evalLP(read("(quote (1 2 3))", &state), &state)
    //evalLP(read("t", &state), &state)
    //evalLP(read("f", &state), &state)
    //evalLP(read("(> 2 1)", &state), &state)

    //evalLP(read("(define add (lambda (a b) (+ a b)))", &state), &state)
    //evalLP(read("(add 1 2)", &state), &state)
    //evalLP(read("(if t \"fart\" \"poop\")", state), state)
    //println(reverseForReader(evalL(read("(cons 1 (cons 2 (cons 3 4)))", state), state)), state)
    //println(reverseForReader(evalL(read("(cons 1 2)", state), state)), state)
    //evalLP(read("(cdr (quote (1 2 . 3)))", state), state)
    //evalLP(read("(quote (2 . 3))", state), state)
}
