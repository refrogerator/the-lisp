package main

import "base:runtime"
import "core:time"
import "core:fmt"
import "core:slice"

Allocation :: struct {
    marked: bool,
    pointer: []byte,
}

MarkSweepGC :: struct {
    interpreter: ^InterpreterState,
    backing_allocator: runtime.Allocator,
    allocations: [dynamic]Allocation,
    allocs_since_last_gc: int,
    paused: bool,
    used: int,
    allocated: int,
    pause_time: time.Duration,
}

mark_sweep_pause :: proc(allocator: runtime.Allocator) {
    allocator := (^MarkSweepGC)(allocator.data)
    allocator.paused = true
}

mark_sweep_unpause :: proc(allocator: runtime.Allocator) {
    allocator := (^MarkSweepGC)(allocator.data)
    allocator.paused = false
}

mark_sweep_find_alloc :: proc(allocator: ^MarkSweepGC, pointer: rawptr) -> ^Allocation {
    for &allocation in allocator.allocations {
        if pointer == raw_data(allocation.pointer) {
            return &allocation
        }
    }
    return nil
}

mark_sweep_run_gc :: proc(allocator: ^MarkSweepGC) {
    if allocator.paused {
        return
    }

    start := time.now()

    allocator.paused = true

    // an attempt was made to use conservative roots
    for &allocation in allocator.allocations { // this thing has no actual roots yet KEk
        allocation.marked = false

        base := cast([^]rawptr)raw_data(allocation.pointer)
        for i := 0; i < (len(allocation.pointer) / size_of(rawptr)); i += 1{
            if alloc := mark_sweep_find_alloc(allocator, base[i]); alloc != nil {
                alloc.marked = true
            }
        }
    }
    //
    //for _, global in allocator.interpreter.globals {
    //    if alloc := mark_sweep_find_alloc(allocator, cast(rawptr)global); alloc != nil {
    //        alloc.marked = true
    //    }
    //}
    //
    //for locals in allocator.interpreter.stack {
    //    for _, local in locals {
    //        if alloc := mark_sweep_find_alloc(allocator, cast(rawptr)local); alloc != nil {
    //            alloc.marked = true
    //        }
    //    }
    //}

    mark_sweep_mark_alloc :: proc(node: ^Node, allocator: ^MarkSweepGC) {
        if alloc := mark_sweep_find_alloc(allocator, cast(rawptr)node); alloc != nil {
            alloc.marked = true
        } else {
            //fmt.println("alloc not found")
        }
    }

    mark_sweep_mark_precise :: proc(node: ^Node, allocator: ^MarkSweepGC) {
        if node == nil {
            return
        }
        mark_sweep_mark_alloc(node, allocator)
        switch n in node {
        case Cons:
            mark_sweep_mark_precise(n.car, allocator)
            mark_sweep_mark_precise(n.cdr, allocator)
        case [dynamic]^Node:
            for elt in n {
                mark_sweep_mark_precise(elt, allocator)
            }
        case Macro:
            mark_sweep_mark_precise(n.args, allocator)
            mark_sweep_mark_precise(n.body, allocator)
            for _, capture in n.captures {
                mark_sweep_mark_precise(capture, allocator)
            }
        case Lambda:
            mark_sweep_mark_precise(n.args, allocator)
            mark_sweep_mark_precise(n.body, allocator)
            for _, capture in n.captures {
                mark_sweep_mark_precise(capture, allocator)
            }
        case Number:
        case rune:
        case string:
        case Symbol:
        case bool:
        case Builtin:
        }
    }

    unmark_all :: proc(allocator: ^MarkSweepGC) {
        for &allocation in allocator.allocations {
            allocation.marked = false
        }
    }

    unmark_all(allocator)


    for stack in allocator.interpreter.allocStack {
        for entry in stack {
            //if alloc := mark_sweep_find_alloc(allocator, entry); alloc != nil {
            //    alloc.marked = true
            //}
            mark_sweep_mark_precise(cast(^Node)entry, allocator)
        }
    }

    for _, global in allocator.interpreter.globals {
        //if alloc := mark_sweep_find_alloc(allocator, cast(rawptr)global); alloc != nil {
        //    alloc.marked = true
        //}
        mark_sweep_mark_precise(global, allocator)
    }

    for locals in allocator.interpreter.stack {
        for _, local in locals {
            //if alloc := mark_sweep_find_alloc(allocator, cast(rawptr)local); alloc != nil {
            //    alloc.marked = true
            //}
            mark_sweep_mark_precise(local, allocator)
        }
    }

    freed := 0

    for allocation, i in allocator.allocations {
        if !allocation.marked {
            runtime.mem_free(raw_data(allocation.pointer), allocator.backing_allocator)
            fmt.eprintln("freed", raw_data(allocation.pointer))
            freed += 1
        }
    }

    slice.reverse_sort_by(allocator.allocations[:], proc(i, j: Allocation) -> bool {
        if i.marked {
            return false
        } else {
            if j.marked {
                return true
            } else {
                return false
            }
        }
    })

    resize(&allocator.allocations, len(allocator.allocations) - freed)

    allocator.paused = false

    allocator.allocs_since_last_gc = 0

    allocator.pause_time = time.since(start)

    when ODIN_DEBUG {
        fmt.eprintln("freed", freed, "allocations")
        fmt.eprintln(len(allocator.allocations), "allocations remaining")
        fmt.eprintln(allocator.pause_time)
    }
}

mark_sweep_resize :: proc(allocator: ^MarkSweepGC, old_memory: rawptr, old_size: int, size: int, alignment := runtime.DEFAULT_ALIGNMENT, loc := #caller_location) -> (data: []byte, err: runtime.Allocator_Error) {
    allocation := mark_sweep_find_alloc(allocator, old_memory)
    data, err = runtime.mem_resize(old_memory, old_size, size, alignment, allocator.backing_allocator, loc)
    allocation.pointer = data

    if err != nil {
        return
    }
    allocator.allocated -= old_size
    allocator.used -= old_size
    allocator.allocated += size
    allocator.used += size
    return data, nil
}

mark_sweep_alloc :: proc(allocator: ^MarkSweepGC, size: int, alignment := runtime.DEFAULT_ALIGNMENT, loc := #caller_location) -> (data: []byte, err: runtime.Allocator_Error) {
    //if allocator.allocs_since_last_gc >= 20 {
        mark_sweep_run_gc(allocator)
    //}

    allocator.allocs_since_last_gc += 1
    allocator.used += size
    allocator.allocated += size
    data, err = runtime.mem_alloc(size, alignment, allocator.backing_allocator, loc)
    append(last(allocator.interpreter.allocStack), raw_data(data))
    append(&allocator.allocations, Allocation { true, data })
    return
}

@(require_results)
mark_sweep_gc :: proc(state: ^InterpreterState) -> runtime.Allocator {
    msgc := new(MarkSweepGC)
    msgc^ = MarkSweepGC {
        state,
        context.allocator,
        make([dynamic]Allocation, 0, 100, context.allocator),
        0,
        false,
        0,
        0,
        time.Duration(0)
    }
    return runtime.Allocator {
        procedure = mark_sweep_gc_proc,
        data = msgc
    }
}

mark_sweep_gc_proc :: proc(allocator_data: rawptr, mode: runtime.Allocator_Mode,
                           size, alignment: int,
                           old_memory: rawptr, old_size: int,
                           location := #caller_location) -> (data: []byte, err: runtime.Allocator_Error) {
    allocator := (^MarkSweepGC)(allocator_data)

    switch mode {
    case .Alloc, .Alloc_Non_Zeroed:
        return mark_sweep_alloc(allocator, size, alignment, location)
    case .Free:
        return nil, .Mode_Not_Implemented
    case .Free_All:
        return nil, .Mode_Not_Implemented
    case .Resize, .Resize_Non_Zeroed:
        return mark_sweep_resize(allocator, old_memory, old_size, size, alignment, location)
    case .Query_Features, .Query_Info:
        return nil, .Mode_Not_Implemented
    }
    return nil, nil
}
